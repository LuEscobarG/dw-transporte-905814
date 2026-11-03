terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}


# ============================================================
# PROVIDER DE AZURE
# ============================================================

# Se autentica usando la sesión iniciada con:
# az login
provider "azurerm" {
  features {}
}


# ============================================================
# VARIABLES LOCALES
# ============================================================

locals {

  # Incrementar este valor solamente si quieres volver a
  # ejecutar completamente los scripts del ERP.
  #
  # Ejemplo:
  # "1" -> primera carga
  # "2" -> volver a cargar
  erp_seed_version = "1"

  # Busca automáticamente todos los CSV y Excel.
  raw_files = setunion(
    fileset(path.module, "datos_csv/*.csv"),
    fileset(path.module, "datos_xls/*.xlsx"),
  )

  # Scripts SQL que se ejecutarán en este orden.
  erp_sql_scripts = [
    "01_crear_esquema.sql",
    "02_catalogos.sql",
    "03_datos_2024.sql",
    "04_datos_2025.sql",
  ]
}


# ============================================================
# 1. RESOURCE GROUP
# ============================================================

resource "azurerm_resource_group" "rg" {

  name = "rg-ucb-transporte-9205814"

  # El Resource Group ya fue creado en esta región.
  location = "brazilsouth"
}


# ============================================================
# 2. STORAGE ACCOUNT
# ============================================================

resource "azurerm_storage_account" "storage" {

  # El nombre del Storage Account debe ser globalmente único.
  # Usamos tu ID para diferenciarlo.
  name = "saucbtransporte9205814"

  resource_group_name = azurerm_resource_group.rg.name

  # Región permitida por tu suscripción Azure for Students.
  location = "westus"

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  # Data Lake Storage Gen2.
  is_hns_enabled = true

  # Mantiene la configuración utilizada por el proyecto original.
  allow_nested_items_to_be_public = true

  min_tls_version = "TLS1_2"
}


# ============================================================
# 3. CONTENEDOR RAW
# ============================================================

resource "azurerm_storage_container" "raw" {

  name = "raw"

  storage_account_name = azurerm_storage_account.storage.name

  # Mantiene la configuración de la práctica original.
  container_access_type = "blob"
}


# ============================================================
# 4. CARGA AUTOMÁTICA DE CSV Y EXCEL
# ============================================================

resource "azurerm_storage_blob" "raw_files" {

  # Se crea un blob por cada archivo encontrado.
  for_each = local.raw_files

  # Conserva datos_csv/... o datos_xls/... dentro del contenedor.
  name = each.value

  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.raw.name

  type = "Block"

  source = "${path.module}/${each.value}"

  # Si cambia el contenido del archivo,
  # Terraform detectará el cambio.
  content_md5 = filemd5(
    "${path.module}/${each.value}"
  )

  # Detecta automáticamente CSV o Excel.
  content_type = (
    length(regexall("\\.csv$", lower(each.value))) > 0
    ? "text/csv"
    : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  )
}


# ============================================================
# 5. AZURE SQL SERVER
# ============================================================

resource "azurerm_mssql_server" "sql_server" {

  # También debe ser globalmente único.
  name = "sql-ucb-transporte-9205814"

  resource_group_name = azurerm_resource_group.rg.name

  # Región permitida por tu suscripción Azure for Students.
  location = "westus"

  version = "12.0"

  # Usuario administrador SQL.
  administrator_login = "admintransporte"

  # La contraseña NO se escribe aquí.
  # Terraform la obtiene desde variables.tf.
  administrator_login_password = var.sql_admin_password

  minimum_tls_version = "1.2"
}


# ============================================================
# 6. FIREWALL SQL
# ============================================================

# Permite conexiones IPv4.
# Se mantiene así porque corresponde al escenario
# proporcionado por el docente.
resource "azurerm_mssql_firewall_rule" "allow_all_ipv4" {

  name = "AllowAllIPv4"

  server_id = azurerm_mssql_server.sql_server.id

  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}


# Permite conexiones desde servicios Azure,
# por ejemplo Azure Data Factory.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {

  name = "AllowAzureServices"

  server_id = azurerm_mssql_server.sql_server.id

  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}


# ============================================================
# 7. BASES DE DATOS
# ============================================================

# Terraform creará:
#
# erp_transporte_db
# dw_transporte

resource "azurerm_mssql_database" "db" {

  for_each = toset([
    "erp_transporte_db",
    "dw_transporte"
  ])

  name = each.value

  server_id = azurerm_mssql_server.sql_server.id

  collation = "SQL_Latin1_General_CP1_CI_AS"

  sku_name = "GP_S_Gen5_1"

  max_size_gb = 32

  min_capacity = 0.5

  auto_pause_delay_in_minutes = 60
}


# ============================================================
# 8. CARGA AUTOMÁTICA DEL ERP
# ============================================================

resource "terraform_data" "erp_schema" {

  # Terraform vuelve a ejecutar esta sección cuando:
  #
  # - cambia la base ERP
  # - cambia erp_seed_version
  triggers_replace = [
    azurerm_mssql_database.db["erp_transporte_db"].id,
    local.erp_seed_version,
  ]

  # Esperamos a que las reglas del firewall estén creadas.
  depends_on = [
    azurerm_mssql_firewall_rule.allow_all_ipv4,
    azurerm_mssql_firewall_rule.allow_azure_services,
  ]

  # Comprueba que existan los cuatro scripts SQL.
  lifecycle {

    precondition {

      condition = alltrue([
        for script in local.erp_sql_scripts :
        fileexists("${path.module}/sql/${script}")
      ])

      error_message = "Deben existir los cuatro scripts SQL dentro de la carpeta sql/."
    }
  }


  # ==========================================================
  # EJECUCIÓN DE SQLCMD DESDE WINDOWS POWERSHELL
  # ==========================================================

  provisioner "local-exec" {

    interpreter = [
      "PowerShell",
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-Command"
    ]

    environment = {

      SQL_SERVER = (
        azurerm_mssql_server.sql_server
        .fully_qualified_domain_name
      )

      SQL_DATABASE = (
        azurerm_mssql_database.db[
          "erp_transporte_db"
        ].name
      )

      SQL_USER = (
        azurerm_mssql_server.sql_server
        .administrator_login
      )

      SQLCMDPASSWORD = (
        azurerm_mssql_server.sql_server
        .administrator_login_password
      )

      SQL_SCRIPT_DIR = abspath(
        "${path.module}/sql"
      )

      SQL_SCRIPT_LIST = join(
        ";",
        local.erp_sql_scripts
      )
    }

    command = <<-POWERSHELL

      $ErrorActionPreference = "Stop"

      Write-Host ""
      Write-Host "=========================================="
      Write-Host "CARGA AUTOMATICA ERP"
      Write-Host "=========================================="
      Write-Host ""

      # ------------------------------------------------------
      # Verificar SQLCMD
      # ------------------------------------------------------

      if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {

          Write-Error "sqlcmd no esta instalado o no se encuentra en PATH."

          exit 1
      }

      Write-Host "sqlcmd encontrado correctamente."

      Write-Host ""
      Write-Host "Servidor SQL:"
      Write-Host $env:SQL_SERVER

      Write-Host ""
      Write-Host "Base de datos:"
      Write-Host $env:SQL_DATABASE


      # ------------------------------------------------------
      # Esperar a que Azure SQL esté disponible
      # ------------------------------------------------------

      Write-Host ""
      Write-Host "Esperando conexion con Azure SQL..."

      $connected = $false

      for ($attempt = 1; $attempt -le 12; $attempt++) {

          Write-Host "Intento $attempt de 12..."

          sqlcmd `
              -S $env:SQL_SERVER `
              -d $env:SQL_DATABASE `
              -U $env:SQL_USER `
              -P $env:SQLCMDPASSWORD `
              -b `
              -l 30 `
              -Q "SET NOCOUNT ON; SELECT 1;" `
              2>$null

          if ($LASTEXITCODE -eq 0) {

              $connected = $true

              Write-Host "Conexion SQL correcta."

              break
          }

          Write-Host "SQL todavia no esta disponible."

          Start-Sleep -Seconds 10
      }


      # ------------------------------------------------------
      # Validar conexión
      # ------------------------------------------------------

      if (-not $connected) {

          Write-Error "No fue posible conectarse a la base ERP despues de varios intentos."

          exit 1
      }


      # ------------------------------------------------------
      # Ejecutar los cuatro scripts SQL
      # ------------------------------------------------------

      $scripts = $env:SQL_SCRIPT_LIST.Split(";")

      foreach ($scriptName in $scripts) {

          $scriptPath = Join-Path `
              $env:SQL_SCRIPT_DIR `
              $scriptName

          # Verificar existencia.
          if (-not (Test-Path $scriptPath)) {

              Write-Error "No existe el archivo SQL: $scriptPath"

              exit 1
          }

          Write-Host ""
          Write-Host "------------------------------------------"
          Write-Host "Ejecutando:"
          Write-Host $scriptName
          Write-Host "------------------------------------------"

          sqlcmd `
              -S $env:SQL_SERVER `
              -d $env:SQL_DATABASE `
              -U $env:SQL_USER `
              -P $env:SQLCMDPASSWORD `
              -b `
              -l 30 `
              -i $scriptPath

          if ($LASTEXITCODE -ne 0) {

              Write-Error "Fallo la ejecucion del archivo $scriptName"

              exit 1
          }

          Write-Host "$scriptName ejecutado correctamente."
      }

      Write-Host ""
      Write-Host "=========================================="
      Write-Host "ERP CARGADO CORRECTAMENTE"
      Write-Host "=========================================="
      Write-Host ""

    POWERSHELL
  }
}


# ============================================================
# 9. AZURE DATA FACTORY
# ============================================================

resource "azurerm_data_factory" "adf" {

  # Identificado con tu ID.
  name = "adf-ucb-transporte-9205814"

  resource_group_name = (
    azurerm_resource_group.rg.name
  )

  # Región permitida por tu suscripción Azure for Students.
  location = "westus"
}
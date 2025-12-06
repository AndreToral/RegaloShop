#!/bin/bash
# Script para forzar la eliminación de secrets de Aurora
# Elimina específicamente los secrets de credentials y URL de Aurora

set -e

PROJECT_NAME="${1:-tienda}"
REGION="${2:-us-east-1}"

echo "�️  Cleanup Aurora Secrets Manager"
echo "   Project: $PROJECT_NAME"
echo "   Region: $REGION"
echo ""

# Secrets específicos de Aurora a eliminar
SECRETS_TO_DELETE=(
  "${PROJECT_NAME}-aurora-credentials"
  "${PROJECT_NAME}-aurora-url"
)

echo "🚀 Eliminando secrets de Aurora con --force-delete-without-recovery..."
echo ""

for secret in "${SECRETS_TO_DELETE[@]}"; do
  echo "   ▶ Eliminando: $secret"
  if aws secretsmanager delete-secret \
    --secret-id "$secret" \
    --force-delete-without-recovery \
    --region "$REGION" 2>&1; then
    echo "     ✅ Eliminado exitosamente"
  else
    echo "     ℹ️  Secret no encontrado o ya eliminado (ignorando)"
  fi
done

echo ""
echo "✅ Limpieza de secrets de Aurora completada"

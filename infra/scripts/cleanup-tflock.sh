#!/bin/bash
# Script para limpiar locks de Terraform en DynamoDB
# Útil cuando un apply se queda estancado

LOCK_TABLE="${1:-regaloshop-tflock}"
LOCK_ID="${2:-regaloshop-tfstate/regaloshop/terraform.tfstate}"
REGION="${3:-us-east-1}"

echo "🔓 Terraform DynamoDB Lock Cleanup"
echo "   Table: $LOCK_TABLE"
echo "   Lock ID: $LOCK_ID"
echo "   Region: $REGION"
echo ""

# Verificar si el lock existe
echo "🔍 Buscando lock en DynamoDB..."
LOCK_EXISTS=$(aws dynamodb get-item \
  --table-name "$LOCK_TABLE" \
  --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
  --region "$REGION" \
  --query 'Item.LockID' \
  --output text)

if [ -z "$LOCK_EXISTS" ] || [ "$LOCK_EXISTS" = "None" ]; then
  echo "✅ No hay lock activo para eliminar"
  exit 0
fi

echo "⚠️  Lock encontrado:"
echo "   $LOCK_EXISTS"
echo ""
echo "🗑️  Eliminando lock de DynamoDB..."

aws dynamodb delete-item \
  --table-name "$LOCK_TABLE" \
  --key "{\"LockID\":{\"S\":\"$LOCK_ID\"}}" \
  --region "$REGION" || {
  echo "❌ Error eliminando lock"
  exit 1
}

echo "✅ Lock eliminado exitosamente"
echo ""
echo "💡 Ahora puedes ejecutar terraform plan/apply nuevamente"

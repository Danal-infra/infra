#!/bin/bash

# ==============================================================================
# [Vault Integrated Seeding Script]
# - 목적: Vault KV 엔진에 필요한 모든 초기 데이터(환경변수, 인증서)를 일괄 주입
# - 대상 1: secret/data/infra/env (환경변수)
# - 대상 2: secret/data/certs/wildcard-infra (인증서)
# - 전제 조건: vault login 완료 상태, ./certs 폴더에 인증서 존재
# ==============================================================================

# Vault 주소 설정 (환경에 맞게 수정)
export VAULT_ADDR="https://vlt.infra.lan:8200"
# TLS 검증 무시 (사설 인증서인 경우)
export VAULT_SKIP_VERIFY="true"

# 인증서 파일 경로 정의
CERT_FILE="./certs/vault.crt"
KEY_FILE="./certs/vault.key"

# ------------------------------------------------------------------------------
# 1. 사전 점검
# ------------------------------------------------------------------------------
echo ">>> [1/4] 사전 점검 (Vault 상태 및 파일 확인)..."

if ! vault status >/dev/null 2>&1; then
  echo "❌ ERROR: Vault에 연결할 수 없습니다. VAULT_ADDR 및 토큰을 확인하세요."
  echo "   Tip: 'vault login'을 먼저 실행했는지 확인하세요."
  exit 1
fi

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
  echo "❌ ERROR: 인증서 파일을 찾을 수 없습니다."
  echo "   경로 확인: $CERT_FILE, $KEY_FILE"
  echo "   Tip: 'site.yml'을 먼저 실행하여 인증서를 생성하세요."
  exit 1
fi

echo "✅ Vault 연결 확인됨."
echo "✅ 인증서 파일 확인됨."

# ------------------------------------------------------------------------------
# 2. KV 엔진 활성화 확인
# ------------------------------------------------------------------------------
echo ">>> [2/4] KV 엔진(secret/) 활성화 확인..."
# 이미 활성화되어 있으면 에러 메시지가 뜨지만 무시하고 진행 (|| true)
vault secrets enable -path=secret kv-v2 2>/dev/null || true

# ------------------------------------------------------------------------------
# 3. 인증서 업로드 (secret/certs/wildcard-infra)
# ------------------------------------------------------------------------------
echo ">>> [3/4] 인증서 업로드 (secret/certs/wildcard-infra)..."

# @심볼을 사용하여 파일 내용을 직접 전송
vault kv put secret/certs/wildcard-infra \
  cert=@$CERT_FILE \
  key=@$KEY_FILE

if [ $? -eq 0 ]; then
  echo "✅ 성공: 인증서가 저장되었습니다."
else
  echo "❌ 실패: 인증서 업로드 중 오류 발생."
  exit 1
fi

# ------------------------------------------------------------------------------
# 4. 환경변수 업로드 (secret/infra/env)
# ------------------------------------------------------------------------------
# ...
echo ">>> [4/4] 환경변수 데이터 주입 (secret/infra/env)..."

# Generate a strong secret key (50+ chars)
GENERATED_SECRET_KEY=$(openssl rand -hex 50)

# 주의: 실제 운영 시에는 '0000' 대신 강력한 난수 비밀번호를 사용해야 합니다.
vault kv put secret/infra/env \
  DB_ROOT_PASS='DBPASSWD' \
  POSTGRES_PASSWORD='PGPASSWORD' \
  DB_HOST='postgres' \
  DB_NAME='netbox' \
  DB_USER='netbox' \
  DB_PASSWORD='NETBOX' \
  REDIS_HOST='redis' \
  REDIS_PORT='6379' \
  SECRET_KEY="$GENERATED_SECRET_KEY" \
  ALLOWED_HOSTS='*'

if [ $? -eq 0 ]; then
  echo "✅ 성공: 환경변수 데이터가 저장되었습니다."
  echo "----------------------------------------------------------------"
  echo "🎉 모든 시딩 작업이 완료되었습니다."
  echo "   - 인증서 확인: vault kv get secret/certs/wildcard-infra"
  echo "   - 변수 확인:   vault kv get secret/infra/env"
else
  echo "❌ 실패: 환경변수 주입 중 오류 발생."
  exit 1
fi

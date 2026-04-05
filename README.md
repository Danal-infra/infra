# 인프라 자동화 가이드 (Infra Automation Guide)

이 프로젝트는 **HashiCorp Vault 클러스터(HA)**와 이를 기반으로 하는 **NetBox, Nexus Repository Manager** 등의 인프라 서비스를 자동 배포하기 위한 Ansible Playbook 세트입니다.

## 🚀 권장 배포 순서 (Deployment Roadmap)

인프라의 의존성을 고려하여 반드시 다음 순서로 실행하십시오.

| 순서 | 작업 내용 | 실행 명령어 |
| :--- | :--- | :--- |
| **1** | 스토리지 및 마운트 구성 | `ansible-playbook -i inventory/hosts setup-storage.yml` |
| **2** | 핵심 인프라 및 Vault 구축 | `ansible-playbook -i inventory/hosts site.yml` |
| **3** | **Vault 초기화 및 잠금 해제** | (아래 'Vault 수동 설정' 섹션 참조) |
| **4** | Vault 초기 데이터 주입 | `./vault-seeding.sh` |
| **5** | Vault AppRole 권한 설정 | `ansible-playbook -i inventory/hosts setup-vault-approle.yml` |
| **6** | NetBox / Nexus 앱 배포 | `ansible-playbook -i inventory/hosts setup-infra-apps.yml` |
| **7** | Vault Agent (Secret 동기화) | `ansible-playbook -i inventory/hosts setup-vault-agent.yml` |

---

## 🔐 Vault 수동 설정 (Manual Setup)

`site.yml` 실행 직후, Vault는 설치되었으나 **초기화(Initialized: false)** 및 **잠김(Sealed: true)** 상태입니다. 다음 명령어를 통해 활성화해야 합니다.

### 1. 환경 변수 설정
```bash
export VAULT_ADDR="https://vlt.infra.lan:8200"
export VAULT_SKIP_VERIFY="true"
```

### 2. Vault 초기화 (최초 1회)
```bash
vault operator init -key-shares=5 -key-threshold=3
```
> **🚨 주의:** 출력되는 `Unseal Key` 5개와 `Initial Root Token`을 반드시 안전한 곳에 기록하십시오.

### 3. Vault 잠금 해제 (Unseal)
생성된 키 중 3개를 각각 입력하여 잠금을 해제합니다. 클러스터의 모든 노드에서 수행하거나 VIP를 통해 수행하십시오.
```bash
# 3번 반복 실행 (각기 다른 Key 입력)
vault operator unseal
```

### 4. Root 로그인 및 시딩
```bash
# 초기화 시 받은 Root Token으로 로그인
vault login -address=$VAULT_ADDR

# 초기 데이터(인증서, 환경변수) 주입
./vault-seeding.sh
```

---

## 📂 프로젝트 구조 (Project Structure)

- `site.yml`: Vault HA 클러스터 및 OS 기본 설정 마스터 플레이북.
- `setup-infra-apps.yml`: NetBox, Nexus, Traefik (Docker Compose 기반) 배포.
- `vault-seeding.sh`: Vault KV 엔진 활성화 및 초기 Secret(DB 패스워드, 인증서) 주입 스크립트.
- `inventory/group_vars/all.yml`: 도메인, IP, 스토리지 경로 등 전역 변수 설정.
- `roles/vault`: Vault 바이너리 설치 및 Keepalived HA 구성 역할.

## 🛠 유지보수 (Maintenance)

- **보안 점검**: `ansible-playbook -i inventory/hosts check-hardening.yml` 실행.
- **백업 실행**: `ansible-playbook -i inventory/hosts run-rear-backup.yml` (ReaR 기반 OS 백업).
- **인증서 갱신**: `certs/` 폴더의 파일을 교체한 후 `./vault-seeding.sh`를 재실행하여 Vault에 반영하십시오.

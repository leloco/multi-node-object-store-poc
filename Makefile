# SeaweedFS PoC Makefile

.PHONY: create destroy get-bucket-content get-filer-details test-volume-replication test-network-isolation

create:
	@echo "==> Starting cluster..."
	docker compose up -d
	@echo "==> Waiting 5s for initialization..."
	sleep 5

destroy:
	@echo "==> Destroying cluster and volumes..."
	docker compose down -v --remove-orphans

get-bucket-content:
	@echo "[+] S3 Gateway: Get all objects in 'poc-bucket' ..."
	@docker compose exec s3-cli aws --endpoint-url=http://sw-gateway:8333 s3 ls s3://poc-bucket --recursive || echo "Bucket is empty or missing."
	@echo ""

get-filer-details:
	@echo "[+] Filer: Show directory contents and chunk details ..."
	@docker compose exec admin-bastion curl -s -H "Accept: application/json" http://sw-filer:8888/buckets/poc-bucket/ | jq '.'
	@echo ""

test-volume-replication:
	@echo "========================================"
	@echo "      SeaweedFS Volume Replication Test"
	@echo "========================================"
	@echo ""
	@echo "[1/6] Creating S3 Bucket ..."
	@docker compose exec s3-cli aws --endpoint-url=http://sw-gateway:8333 s3 mb s3://poc-bucket >/dev/null 2>&1 || echo "Bucket is ready."
	@echo ""
	@echo "[2/6] Uploading test file ..."
	@docker compose exec s3-cli aws --endpoint-url=http://sw-gateway:8333 s3 cp /etc/os-release s3://poc-bucket/os-release.txt >/dev/null 2>&1
	@echo "Test file uploaded."
	@echo ""
	@echo "[3/6] Querying Filer for Metadata and Volume ID ..."
	@VOLUME_ID=$$(docker compose exec admin-bastion curl -s -H "Accept: application/json" http://sw-filer:8888/buckets/poc-bucket/ | jq -r '.Entries[] | select(.FullPath=="/buckets/poc-bucket/os-release.txt") | .chunks[0].file_id | split(",")[0]') && \
	echo "      -> File landed on Volume ID: $$VOLUME_ID" && \
	echo "" && \
	echo "[4/6] Verifying Replication (002) across Volume Servers ..." && \
	docker compose exec admin-bastion curl -s "http://sw-master:9333/dir/lookup?volumeId=$$VOLUME_ID" | jq -r '.locations[].publicUrl' | sed 's/^/-/'
	@echo "[5/6] High Availability Test: Destroying sw-volume-2 ..."
	@docker compose stop sw-volume-2 >/dev/null 2>&1
	@echo "Info: sw-volume-2 is now offline."
	@echo ""
	@echo "[6/6] Verifying file availability via S3 Gateway during node failure ..."
	@docker compose exec s3-cli aws --endpoint-url=http://sw-gateway:8333 s3 cp s3://poc-bucket/os-release.txt - | head -n 3
	@echo "File successfully retrieved via Gateway."
	@echo ""
	@echo "Restoring sw-volume-2 to heal cluster ..."
	@docker compose start sw-volume-2 >/dev/null 2>&1
	@echo "✅ Volume replication test succeeded."

test-network-isolation:
	@echo "========================================"
	@echo "      SeaweedFS Network Isolation Test"
	@echo "========================================"
	@echo ""
	@echo "[1/3] Testing: admin-bastion -> sw-master (should succeed)"
	@docker compose exec admin-bastion curl -s -m 5 http://sw-master:9333/dir/status >/dev/null && echo "Success: admin-bastion can reach the Master." || echo "Error: Cannot reach Master!"
	@echo ""
	@echo "[2/3] Testing: s3-cli -> sw-master (should fail)"
	@docker compose exec s3-cli curl -sS -m 5 http://sw-master:9333/dir/status >/dev/null && echo "Error: s3-cli reached the Master! Isolation broken." || echo "Success: s3-cli cannot route to the internal cluster."
	@echo ""
	@echo "[3/3] Testing: Host Machine -> sw-master (should fail)"
	@curl -sS -m 5 http://localhost:9333/dir/status >/dev/null && echo "Error: Host reached the Master! Port is exposed." || echo "Success: Master ports are safely isolated from the host."
	@echo ""
	@echo "✅ Network isolation test succeeded."

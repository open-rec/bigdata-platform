# Airflow

This profile runs a small Airflow 3 deployment for OpenRec batch orchestration:

- PostgreSQL metadata database;
- API server and Web UI;
- scheduler with `LocalExecutor`;
- standalone DAG processor.

It intentionally has no Celery broker or permanent worker pool. Add version-controlled DAG files to
`dags/`; the directory is mounted read-only into every Airflow component.

```shell
./platform.sh pull airflow
./platform.sh up airflow
./platform.sh smoke airflow
./platform.sh shell airflow
```

The UI is at `http://localhost:8091` by default. Airflow's Simple Auth Manager generates the
password for the configured `admin` user on first start. Read it without printing unrelated logs:

```shell
docker compose --profile airflow exec airflow-api-server \
  python -c 'import json; print(json.load(open("/opt/airflow/logs/simple_auth_manager_passwords.json.generated"))["admin"])'
```

Change `AIRFLOW_ADMIN_USERS`, database credentials, image version, and host port in `.env`. Simple
Auth Manager is appropriate for this local cluster example; use an external auth manager and proper
secrets before exposing Airflow beyond a trusted network.

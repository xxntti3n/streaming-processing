"""Add Trino Iceberg database to Superset (idempotent)."""
import os
import sys


def run():
    from superset.app import create_app
    from superset.extensions import db

    try:
        from superset.models.core import Database
    except ImportError:
        from superset.connectors.sqla.models import Database

    app = create_app()
    with app.app_context():
        name = os.environ.get("TRINO_DB_NAME", "Trino Iceberg")
        uri = os.environ.get("TRINO_SQLALCHEMY_URI", "trino://admin@trino:8080/iceberg")
        existing = db.session.query(Database).filter_by(database_name=name).first()
        if existing:
            if existing.sqlalchemy_uri != uri:
                existing.sqlalchemy_uri = uri
                db.session.commit()
                print(f"Updated database '{name}' URI.", file=sys.stderr)
            else:
                print(f"Database '{name}' already exists.", file=sys.stderr)
            return
        db_obj = Database(
            database_name=name,
            sqlalchemy_uri=uri,
            expose_in_sqllab=True,
        )
        db.session.add(db_obj)
        db.session.commit()
        print(f"Added database '{name}' with URI {uri}.", file=sys.stderr)


if __name__ == "__main__":
    run()

# ─── Project Template ────────────────────────────────────────────
# Copy this directory to create a new project stack:
#
#   cp -r infrastructure/projects/_template infrastructure/projects/<my_project>
#
# Then:
#   1. Edit variables.tf     - adjust descriptions if needed
#   2. Edit tables.tf        - define your tables (Standard in RAW, Iceberg elsewhere)
#   3. Edit jobs.tf          - define your Glue Jobs
#   4. Edit optimizers.tf    - wire optimizers for each Iceberg table
#   5. Edit pipelines.tf     - compose jobs into StepFunction pipelines
#   6. Wire the project in   infrastructure/projects/main.tf
#
# Hierarchy:  Domain (this repo) > Project (this directory) > Resources
# ─────────────────────────────────────────────────────────────────

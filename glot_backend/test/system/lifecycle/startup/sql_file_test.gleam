import glot_backend/system/lifecycle/startup/sql_file

pub fn parse_filename_splits_version_and_name_test() {
  assert sql_file.parse_filename("0001_init.sql") == Ok(#("0001", "init"))
}

pub fn parse_filename_rejects_missing_name_test() {
  assert sql_file.parse_filename("0001.sql")
    == Error("Invalid migration filename: 0001.sql")
}

pub fn validate_migration_filenames_requires_bootstrap_first_test() {
  assert sql_file.validate_migrations([
      "0001_init.sql",
    ])
    == Error("First migration must be 0000_bootstrap.sql, got 0001_init.sql")
}

pub fn validate_migration_filenames_rejects_duplicate_versions_test() {
  assert sql_file.validate_migrations([
      "0000_bootstrap.sql",
      "0001_init.sql",
      "0001_more.sql",
    ])
    == Error("Duplicate migration version: 0001")
}

pub fn validate_seed_filenames_allows_no_bootstrap_test() {
  assert sql_file.validate_seeds([
      "0001_dev_seed.sql",
    ])
    == Ok([
      sql_file.SqlFile(
        version: "0001",
        name: "dev_seed",
        filename: "0001_dev_seed.sql",
      ),
    ])
}

pub fn validate_seed_filenames_rejects_duplicate_versions_test() {
  assert sql_file.validate_seeds([
      "0001_dev_seed.sql",
      "0001_more_seed.sql",
    ])
    == Error("Duplicate migration version: 0001")
}

"""Generic auto-discovery tests for Glue job scripts.

Automatically finds every job_*.py under src/jobs/ and validates:
  - Valid Python syntax (compiles without errors)
  - Defines a callable main() function
  - Uses only core.* imports (no awsglue or boto3 at module level)
  - Has an ``if __name__ == "__main__"`` guard

No manual test creation needed - just add a new job and it is tested.
"""

import ast
from pathlib import Path

import pytest

# ── Discovery ────────────────────────────────────────────────────

JOBS_ROOT = Path(__file__).resolve().parent.parent / "src" / "jobs"

FORBIDDEN_IMPORTS = {"awsglue", "boto3", "botocore"}


def _discover_jobs():
    """Yield (project_name, job_path) for every job_*.py under src/jobs/."""
    if not JOBS_ROOT.exists():
        return
    for job_file in sorted(JOBS_ROOT.rglob("job_*.py")):
        project = job_file.parent.name
        yield pytest.param(job_file, id=f"{project}/{job_file.name}")


ALL_JOBS = list(_discover_jobs())


# ── Tests ────────────────────────────────────────────────────────


@pytest.mark.skipif(not ALL_JOBS, reason="No job scripts found")
class TestJobScripts:
    """Generic validations applied to every discovered job script."""

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_valid_python_syntax(self, job_path):
        """Job file must be valid Python."""
        source = job_path.read_text(encoding="utf-8")
        compile(source, str(job_path), "exec")

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_defines_main_function(self, job_path):
        """Job file must define a callable main()."""
        tree = ast.parse(job_path.read_text(encoding="utf-8"))
        func_names = [node.name for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)]
        assert "main" in func_names, f"{job_path.name} must define a main() function"

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_has_name_guard(self, job_path):
        """Job file must have an ``if __name__ == "__main__"`` block."""
        source = job_path.read_text(encoding="utf-8")
        assert "__name__" in source and "__main__" in source, (
            f'{job_path.name} must have: if __name__ == "__main__"'
        )

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_no_forbidden_imports(self, job_path):
        """Job scripts must not import awsglue or boto3 directly."""
        tree = ast.parse(job_path.read_text(encoding="utf-8"))
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    root = alias.name.split(".")[0]
                    assert root not in FORBIDDEN_IMPORTS, (
                        f"{job_path.name} imports '{alias.name}' - use core.* instead"
                    )
            elif isinstance(node, ast.ImportFrom) and node.module:
                root = node.module.split(".")[0]
                assert root not in FORBIDDEN_IMPORTS, (
                    f"{job_path.name} imports from '{node.module}' - use core.* instead"
                )

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_uses_core_imports(self, job_path):
        """Job file should import at least one module from core.*."""
        tree = ast.parse(job_path.read_text(encoding="utf-8"))
        has_core = False
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.module and node.module.startswith("core"):
                has_core = True
                break
        assert has_core, f"{job_path.name} should import from core.*"

    @pytest.mark.parametrize("job_path", ALL_JOBS)
    def test_has_docstring(self, job_path):
        """Job file should have a module-level docstring."""
        tree = ast.parse(job_path.read_text(encoding="utf-8"))
        assert (
            tree.body
            and isinstance(tree.body[0], ast.Expr)
            and isinstance(tree.body[0].value, ast.Constant)
            and isinstance(tree.body[0].value.value, str)
        ), f"{job_path.name} should have a module-level docstring"

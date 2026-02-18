#!/usr/bin/env python3
"""Unit tests for t4a - Task Queue for Agents

Run with: python3 test_t4a.py
"""
import unittest
import tempfile
import shutil
import os
import sys
import json
import yaml
from pathlib import Path
from datetime import datetime, timezone, timedelta

SCRIPT_DIR = Path(__file__).parent
T4A_SCRIPT = SCRIPT_DIR / "t4a"

def run_t4a(*args, env=None):
    """Run t4a command and return stdout, stderr, returncode"""
    import subprocess
    test_env = os.environ.copy()
    if env:
        test_env.update(env)
    result = subprocess.run(
        [sys.executable, str(T4A_SCRIPT)] + list(args),
        capture_output=True, text=True, env=test_env
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode

class TestT4ABase(unittest.TestCase):
    def setUp(self):
        self.test_dir = Path(tempfile.mkdtemp(prefix="t4a_test_"))
        self.env = {"T4A_DIR": str(self.test_dir)}
    
    def tearDown(self):
        if self.test_dir.exists():
            shutil.rmtree(self.test_dir)
    
    def t4a(self, *args):
        return run_t4a(*args, env=self.env)

class TestJobCreation(TestT4ABase):
    def test_create_basic_job(self):
        out, err, code = self.t4a("add", "Test prompt")
        self.assertEqual(code, 0)
        self.assertTrue(out.startswith("job-"))
    
    def test_create_job_with_priority(self):
        out, err, code = self.t4a("add", "Test", "--priority", "80")
        self.assertEqual(code, 0)
        job_id = out.split()[0]
        out2, _, _ = self.t4a("status", job_id)
        self.assertIn("Priority: 80", out2)
    
    def test_create_job_with_gpu(self):
        out, err, code = self.t4a("add", "GPU task", "--gpu", "2")
        self.assertEqual(code, 0)
        self.assertIn("gpu: 2", out)
    
    def test_create_job_with_approval(self):
        out, err, code = self.t4a("add", "Sensitive", "--requires-approval")
        self.assertEqual(code, 0)
        self.assertIn("needs approval", out)

class TestJobLifecycle(TestT4ABase):
    def test_list_jobs(self):
        self.t4a("add", "Job 1")
        self.t4a("add", "Job 2")
        out, _, code = self.t4a("list")
        self.assertEqual(code, 0)
        self.assertIn("Job 1", out)
        self.assertIn("Job 2", out)
    
    def test_claim_job(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        out, _, code = self.t4a("claim", job_id)
        self.assertEqual(code, 0)
        self.assertEqual(out, job_id)
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Status: running", status)
    
    def test_complete_job(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("claim", job_id)
        out, _, code = self.t4a("complete", job_id, "--summary", "Done!")
        self.assertEqual(code, 0)
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Status: done", status)
    
    def test_fail_job(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("claim", job_id)
        out, _, code = self.t4a("fail", job_id, "--error", "Something went wrong")
        self.assertEqual(code, 0)
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Status: failed", status)
    
    def test_pause_job(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("claim", job_id)
        out, _, code = self.t4a("pause", job_id)
        self.assertEqual(code, 0)
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Status: paused", status)

class TestPriority(TestT4ABase):
    def test_priority_ordering(self):
        self.t4a("add", "Low", "--priority", "10")
        self.t4a("add", "High", "--priority", "90")
        self.t4a("add", "Medium", "--priority", "50")
        out, _, _ = self.t4a("list")
        lines = out.strip().split("\n")
        self.assertIn("High", lines[0])
        self.assertIn("Medium", lines[1])
        self.assertIn("Low", lines[2])
    
    def test_update_priority(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("priority", job_id, "99")
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Priority: 99", status)

class TestProgress(TestT4ABase):
    def test_set_progress(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("claim", job_id)
        self.t4a("progress", job_id, "50", "--message", "Halfway")
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Progress: 50%", status)

class TestCheckpoint(TestT4ABase):
    def test_checkpoint(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        self.t4a("checkpoint", job_id, "--message", "Save point")
        status, _, _ = self.t4a("status", job_id)
        self.assertIn("Save point", status)

class TestApproval(TestT4ABase):
    def test_unapproved_not_claimed(self):
        add_out, _, _ = self.t4a("add", "Test", "--requires-approval")
        job_id = add_out.split()[0]
        claim_out, err, code = self.t4a("claim", job_id)
        self.assertEqual(code, 1)
    
    def test_approve_then_claim(self):
        add_out, _, _ = self.t4a("add", "Test", "--requires-approval")
        job_id = add_out.split()[0]
        self.t4a("approve", job_id)
        claim_out, _, code = self.t4a("claim", job_id)
        self.assertEqual(code, 0)
        self.assertEqual(claim_out, job_id)
    
    def test_approval_status(self):
        add_out, _, _ = self.t4a("add", "Test", "--requires-approval")
        job_id = add_out.split()[0]
        status1, _, _ = self.t4a("status", job_id)
        self.assertIn("PENDING", status1)
        self.t4a("approve", job_id)
        status2, _, _ = self.t4a("status", job_id)
        self.assertIn("APPROVED", status2)

class TestDependencies(TestT4ABase):
    def test_dependency_not_satisfied(self):
        dep_out, _, _ = self.t4a("add", "Dependency")
        dep_id = dep_out.split()[0]
        job_out, _, _ = self.t4a("add", "Main", "--depends-on", dep_id)
        job_id = job_out.split()[0]
        claim_out, err, code = self.t4a("claim", job_id)
        self.assertEqual(code, 1)
    
    def test_dependency_satisfied(self):
        dep_out, _, _ = self.t4a("add", "Dependency")
        dep_id = dep_out.split()[0]
        self.t4a("claim", dep_id)
        self.t4a("complete", dep_id)
        job_out, _, _ = self.t4a("add", "Main", "--depends-on", dep_id)
        job_id = job_out.split()[0]
        claim_out, _, code = self.t4a("claim", job_id)
        self.assertEqual(code, 0)
        self.assertEqual(claim_out, job_id)

class TestLogs(TestT4ABase):
    def test_logs_empty(self):
        add_out, _, _ = self.t4a("add", "Test")
        job_id = add_out.split()[0]
        logs, _, code = self.t4a("logs", job_id)
        self.assertEqual(code, 0)
        self.assertEqual(logs, "")

class TestConfig(TestT4ABase):
    def test_config_get(self):
        out, _, code = self.t4a("config", "get", "resources")
        self.assertEqual(code, 0)
        self.assertIn("api_concurrent", out)
    
    def test_config_set(self):
        self.t4a("config", "set", "resources.api_concurrent", "5")
        out, _, _ = self.t4a("config", "get", "resources.api_concurrent")
        self.assertIn("5", out)

class TestRecover(TestT4ABase):
    def test_recover_no_stalled(self):
        out, _, code = self.t4a("recover")
        self.assertEqual(code, 0)
        self.assertIn("0 stalled", out)

class TestGC(TestT4ABase):
    def test_gc_no_old_jobs(self):
        out, _, code = self.t4a("gc", "--older-than", "1")
        self.assertEqual(code, 0)
        self.assertIn("0 old", out.lower())

class TestStatus(TestT4ABase):
    def test_status_shows_queue(self):
        self.t4a("add", "Job 1")
        self.t4a("add", "Job 2")
        out, _, code = self.t4a("status")
        self.assertEqual(code, 0)
        self.assertIn("2 pending", out)
    
    def test_status_specific_job(self):
        add_out, _, _ = self.t4a("add", "My test job")
        job_id = add_out.split()[0]
        out, _, code = self.t4a("status", job_id)
        self.assertEqual(code, 0)
        self.assertIn(job_id, out)
        self.assertIn("My test job", out)

class TestIDFormat(TestT4ABase):
    def test_job_id_format(self):
        out, _, _ = self.t4a("add", "Test")
        job_id = out.split()[0]
        import re
        self.assertRegex(job_id, r"^job-[a-f0-9]{8}$")

if __name__ == "__main__":
    unittest.main(verbosity=2)

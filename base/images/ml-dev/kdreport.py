"""pytest plugin used by kdrill verify (load with `-p kdreport`).

Prints one line per test in kdrill's check format, never a traceback:
  ok   -> a green tick and the test's docstring (first line) or its name
  fail -> a red cross, the same text, and a short reason
Each test also has a time limit (default 40 s, `@pytest.mark.kd_timeout(n)`).
"""
import os
import signal
import sys

import pytest


def _desc(item):
    doc = (item.function.__doc__ or "").strip().splitlines()
    return doc[0].strip() if doc else item.name.replace("test_", "").replace("_", " ")


class _Timeout(Exception):
    pass


def pytest_configure(config):
    config.addinivalue_line("markers", "kd_timeout(seconds): per-test time limit")


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_call(item):
    m = item.get_closest_marker("kd_timeout")
    limit = int(m.args[0]) if m else 40

    def boom(signum, frame):
        raise _Timeout("took longer than %d s (infinite loop, or far too slow?)" % limit)

    old = signal.signal(signal.SIGALRM, boom)
    signal.alarm(limit)
    try:
        yield
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)


def _reason(report):
    exc = report.longrepr
    text = ""
    try:
        crash = exc.reprcrash
        text = crash.message
        where = os.path.basename(crash.path)
        if where and not where.startswith(("test_", "kdreport", "kdtest")) and "AssertionError" not in text.split(":")[0]:
            text += "   (%s:%d)" % (where, crash.lineno)
    except Exception:
        text = str(exc)
    text = text.replace("AssertionError: ", "").replace("\n", " | ")
    return text[:400]


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    out = yield
    rep = out.get_result()
    if rep.when == "call" or (rep.when == "setup" and rep.failed):
        if rep.passed:
            sys.stdout.write("  \033[32m✓\033[0m %s\n" % _desc(item))
        elif rep.skipped:
            sys.stdout.write("  - %s (skipped)\n" % _desc(item))
        else:
            sys.stdout.write("  \033[31m✗\033[0m %s\n      %s\n" % (_desc(item), _reason(rep)))
        sys.stdout.flush()


def pytest_collectreport(report):
    if report.failed:
        text = str(report.longrepr)
        errs = [l[1:].strip() for l in text.splitlines() if l.startswith("E ")]
        msg = " | ".join(errs[-3:]) if errs else text.splitlines()[-1]
        sys.stdout.write("  \033[31m\u2717\033[0m your code could not be imported\n      %s\n" % msg[:400])
        sys.stdout.flush()


def pytest_report_teststatus(report, config):
    if report.when in ("setup", "call", "teardown"):
        return report.outcome, "", ""


def pytest_terminal_summary(terminalreporter):
    pass

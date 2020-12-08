import os
import pytest
import signal

@pytest.marker.trylast
def pytest_unconfigure():
    print("Forcing test shutdown")
    os.kill(os.getpid(), signal.SIGTERM)

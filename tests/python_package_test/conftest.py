import os
import pytest
import signal

def pytest_unconfigure():
    print("Forcing pytest shutdown")
    os.kill(os.getpid(), signal.SIGTERM)

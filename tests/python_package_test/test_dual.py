"""Tests for dual GPU+CPU support."""

import os
import pytest

import lightgbm as lgb
import numpy as np
from lightgbm.basic import LightGBMError


#@pytest.mark.skipif(
#    os.environ.get("LIGHTGBM_TEST_DUAL_CPU_GPU", None) is None,
#    reason="Only run if appropriate env variable is set",
#)
def test_cpu_works():
    """If compiled appropriately, the same installation will support both GPU and CPU."""
    data = np.random.rand(500, 10)
    label = np.random.randint(2, size=500)
    validation_data = train_data = lgb.Dataset(data, label=label)

    param = {"num_leaves": 31, "objective": "binary", "device": "cpu"}
    lgb.train(param, train_data, 10, valid_sets=[validation_data])


#@pytest.mark.skipif(
#    os.environ.get("LIGHTGBM_TEST_DUAL_CPU_GPU", None) is None,
#    reason="Only run if appropriate env variable is set",
#)
def test_gpu_works():
    """If compiled appropriately, the same installation will support both GPU and CPU."""
    data = np.random.rand(500, 10)
    label = np.random.randint(2, size=500)
    validation_data = train_data = lgb.Dataset(data, label=label)

    param = {"num_leaves": 31, "objective": "binary", "device": "gpu"}
    lgb.train(param, train_data, 10, valid_sets=[validation_data])


if __name__ == "__main__":
    try:
        test_cpu_works()
    except Exception as e:
        print('CPU run FAILED')
        sys.exit(-1)
        print(e)

    try:
        test_gpu_works()
    except Exception as e:
        print('GPU run FAILED')
        print(e)
        sys.exit(-1)

    sys.exit(0)

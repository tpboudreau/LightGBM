
import os
import pytest

import lightgbm as lgb
import numpy as np
from lightgbm.basic import LightGBMError

def test_cpu_works():
    """If compiled appropriately, the same installation will support both GPU and CPU."""
    print('DUAL: CPU')
    data = np.random.rand(500, 10)
    label = np.random.randint(2, size=500)
    validation_data = train_data = lgb.Dataset(data, label=label)

    param = {"num_leaves": 31, "objective": "binary", "device": "cpu"}
    # This will raise an exception if it's an unsupported device:
    gbm = lgb.train(param, train_data, 10, valid_sets=[validation_data])


def test_gpu_works():
    """If compiled appropriately, the same installation will support both GPU and CPU."""
    print('DUAL: GPU')
    TEST_DUAL_MODE = os.getenv('LIGHTGBM_TEST_DUAL_CPU_GPU')
    print('MODE ' + TEST_DUAL_MODE)

    data = np.random.rand(500, 10)
    label = np.random.randint(2, size=500)
    validation_data = train_data = lgb.Dataset(data, label=label)
    param = {"num_leaves": 31, "objective": "binary", "device": "gpu"}

    if TEST_DUAL_MODE == "1": # we do NOT expect OpenCL to be installed, so we expect train('gpu') to fail ...
        try:
            print('DUAL: try')
            gbm = lgb.train(param, train_data, 10, valid_sets=[validation_data])
        except LightGBMError as e:
            if str(e) == "No OpenCL device found": # ... with this message
                print('DUAL: pass')
                pass
            else:
                print('DUAL: raise 1')
                raise
        else:
            print('DUAL: raise 2')
            raise
    else: # MODE must be "2", we expect OpenCL to be installed and train('gpu') to run successfully
        gbm = lgb.train(param, train_data, 10, valid_sets=[validation_data])


if __name__ == "__main__":
    print('DUAL: start')
    test_cpu_works()
    test_gpu_works()
    print('DUAL: done')

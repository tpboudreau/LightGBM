
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
    data = np.random.rand(500, 10)
    label = np.random.randint(2, size=500)
    validation_data = train_data = lgb.Dataset(data, label=label)

    try:
        param = {"num_leaves": 31, "objective": "binary", "device": "gpu"}
        #param = {"num_leaves": 31, "objective": "binary", "device": "gpu", 'gpu_use_dp': True}
        #param = { "objective": "binary", "metric": "auc", "min_data": 10, "num_leaves": 15, #"verbose": -1, "verbose": 1, "num_threads": 0, "max_bin": 255, "device": "gpu" }
        gbm = lgb.train(param, train_data, 10, valid_sets=[validation_data])
        #gbm = lgb.train(param, train_data, 10)
        #gbm = lgb.Booster(param, train_data)
    except LightGBMError as e:
        if str(e) == "No OpenCL device found":
            # This is fine, it means there's no OpenCL device available,
            # and OpenCL device is only searched for if we successfully
            # loaded OpenCL GPU backend.
            pass
        else:
            raise


if __name__ == "__main__":
    print('DUAL: start')
    test_cpu_works()
    test_gpu_works()
    print('DUAL: done')

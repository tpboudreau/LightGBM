/*!
 * Copyright (c) 2016 Microsoft Corporation. All rights reserved.
 * Licensed under the MIT License. See LICENSE file in the project root for license information.
 */
#include <LightGBM/config.h>

#include <LightGBM/utils/common.h>
#include <LightGBM/utils/log.h>
#include <LightGBM/utils/random.h>

#include <limits>

namespace LightGBM {

void Config::KV2Map(std::unordered_map<std::string, std::string>* params, const char* kv) {
  std::vector<std::string> tmp_strs = Common::Split(kv, '=');
  if (tmp_strs.size() == 2 || tmp_strs.size() == 1) {
    std::string key = Common::RemoveQuotationSymbol(Common::Trim(tmp_strs[0]));
    std::string value = "";
    if (tmp_strs.size() == 2) {
      value = Common::RemoveQuotationSymbol(Common::Trim(tmp_strs[1]));
    }
    if (!Common::CheckASCII(key) || !Common::CheckASCII(value)) {
      Log::Fatal("Do not support non-ASCII characters in config.");
    }
    if (key.size() > 0) {
      auto value_search = params->find(key);
      if (value_search == params->end()) {  // not set
        params->emplace(key, value);
      } else {
        Log::Warning("%s is set=%s, %s=%s will be ignored. Current value: %s=%s",
          key.c_str(), value_search->second.c_str(), key.c_str(), value.c_str(),
          key.c_str(), value_search->second.c_str());
      }
    }
  } else {
    Log::Warning("Unknown parameter %s", kv);
  }
}

std::unordered_map<std::string, std::string> Config::Str2Map(const char* parameters) {
  std::unordered_map<std::string, std::string> params;
  auto args = Common::Split(parameters, " \t\n\r");
  for (auto arg : args) {
    KV2Map(&params, Common::Trim(arg).c_str());
  }
  ParameterAlias::KeyAliasTransform(&params);
  return params;
}

static void TransformBoolean(std::string& arg) {

  struct boolean_parameter {
    std::string key;
    size_t length;
  };

  static const std::vector<boolean_parameter> bp =
  {
    { "force_col_wise=", 15 } ,
    { "force_row_wise=", 15 } ,
    { "first_metric_only=", 18 } ,
    { "xgboost_dart_mode=", 18 } ,
    { "uniform_drop=", 13 } ,
    { "pre_partition=", 14 } ,
    { "enable_bundle=", 14 } ,
    { "is_enable_sparse=", 17 } ,
    { "use_missing=", 12 } ,
    { "zero_as_missing=", 16 } ,
    { "two_round=", 10 } ,
    { "save_binary=", 12 } ,
    { "header=", 7 } ,
    { "predict_raw_score=", 18 } ,
    { "predict_leaf_index=", 19 } ,
    { "predict_contrib=", 16 } ,
    { "pred_early_stop=", 16 } ,
    { "predict_disable_shape_check=", 28 } ,
    { "is_unbalance=", 13 } ,
    { "boost_from_average=", 19 } ,
    { "reg_sqrt=", 9 } ,
    { "lambdamart_norm=", 16 } ,
    { "is_provide_training_metric=", 27 } ,
    { "gpu_use_dp=", 11 } ,
  };

  for (const boolean_parameter& p : bp) {
    if ( arg.compare(0, p.length, p.key) == 0 ) {
      if ( arg.compare(arg.length()-2, 2, "=0") == 0 ) {
        arg.replace (arg.end()-1, arg.end(), "-");
      } else if ( arg.compare(arg.length() - 2, 2, "=1") == 0 ) {
        arg.replace (arg.end()-1, arg.end(), "+");
      }
    }
  }

  return;

}

std::unordered_map<std::string, std::string> Config::LoadedStr2Map(const char* parameters) {
  std::unordered_map<std::string, std::string> params;
  auto args = Common::Split(parameters, "\n\r");

  for (auto arg : args) {
    size_t pos = arg.find_first_of(":");
    if (pos != std::string::npos) {
      arg.replace (arg.begin()+pos, arg.begin()+(pos+2), "=");
      arg.erase (arg.begin());
      arg.erase (arg.end()-1);
      TransformBoolean(arg);
      KV2Map(&params, Common::Trim(arg).c_str());
    } else {
      Log::Warning("configuration loaded parameter badly formed: %s", arg);
    }
  }

  ParameterAlias::KeyAliasTransform(&params);

  return params;
}

void GetBoostingType(const std::unordered_map<std::string, std::string>& params, std::string* boosting) {
  std::string value;
  if (Config::GetString(params, "boosting", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    if (value == std::string("gbdt") || value == std::string("gbrt")) {
      *boosting = "gbdt";
    } else if (value == std::string("dart")) {
      *boosting = "dart";
    } else if (value == std::string("goss")) {
      *boosting = "goss";
    } else if (value == std::string("rf") || value == std::string("random_forest")) {
      *boosting = "rf";
    } else {
      Log::Fatal("Unknown boosting type %s", value.c_str());
    }
  }
}

void ParseMetrics(const std::string& value, std::vector<std::string>* out_metric) {
  std::unordered_set<std::string> metric_sets;
  out_metric->clear();
  std::vector<std::string> metrics = Common::Split(value.c_str(), ',');
  for (auto& met : metrics) {
    auto type = ParseMetricAlias(met);
    if (metric_sets.count(type) <= 0) {
      out_metric->push_back(type);
      metric_sets.insert(type);
    }
  }
}

void GetObjectiveType(const std::unordered_map<std::string, std::string>& params, std::string* objective) {
  std::string value;
  if (Config::GetString(params, "objective", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    *objective = ParseObjectiveAlias(value);
  }
}

void GetMetricType(const std::unordered_map<std::string, std::string>& params, std::vector<std::string>* metric) {
  std::string value;
  if (Config::GetString(params, "metric", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    ParseMetrics(value, metric);
  }
  // add names of objective function if not providing metric
  if (metric->empty() && value.size() == 0) {
    if (Config::GetString(params, "objective", &value)) {
      std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
      ParseMetrics(value, metric);
    }
  }
}

void GetTaskType(const std::unordered_map<std::string, std::string>& params, TaskType* task) {
  std::string value;
  if (Config::GetString(params, "task", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    if (value == std::string("train") || value == std::string("training")) {
      *task = TaskType::kTrain;
    } else if (value == std::string("predict") || value == std::string("prediction")
               || value == std::string("test")) {
      *task = TaskType::kPredict;
    } else if (value == std::string("convert_model")) {
      *task = TaskType::kConvertModel;
    } else if (value == std::string("refit") || value == std::string("refit_tree")) {
      *task = TaskType::KRefitTree;
    } else {
      Log::Fatal("Unknown task type %s", value.c_str());
    }
  }
}

void GetDeviceType(const std::unordered_map<std::string, std::string>& params, std::string* device_type) {
  std::string value;
  if (Config::GetString(params, "device_type", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    if (value == std::string("cpu")) {
      *device_type = "cpu";
    } else if (value == std::string("gpu")) {
      *device_type = "gpu";
    } else {
      Log::Fatal("Unknown device type %s", value.c_str());
    }
  }
}

void GetTreeLearnerType(const std::unordered_map<std::string, std::string>& params, std::string* tree_learner) {
  std::string value;
  if (Config::GetString(params, "tree_learner", &value)) {
    std::transform(value.begin(), value.end(), value.begin(), Common::tolower);
    if (value == std::string("serial")) {
      *tree_learner = "serial";
    } else if (value == std::string("feature") || value == std::string("feature_parallel")) {
      *tree_learner = "feature";
    } else if (value == std::string("data") || value == std::string("data_parallel")) {
      *tree_learner = "data";
    } else if (value == std::string("voting") || value == std::string("voting_parallel")) {
      *tree_learner = "voting";
    } else {
      Log::Fatal("Unknown tree learner type %s", value.c_str());
    }
  }
}

void Config::GetAucMuWeights() {
  if (auc_mu_weights.empty()) {
    // equal weights for all classes
    auc_mu_weights_matrix = std::vector<std::vector<double>> (num_class, std::vector<double>(num_class, 1));
    for (size_t i = 0; i < static_cast<size_t>(num_class); ++i) {
      auc_mu_weights_matrix[i][i] = 0;
    }
  } else {
    auc_mu_weights_matrix = std::vector<std::vector<double>> (num_class, std::vector<double>(num_class, 0));
    if (auc_mu_weights.size() != static_cast<size_t>(num_class * num_class)) {
      Log::Fatal("auc_mu_weights must have %d elements, but found %d", num_class * num_class, auc_mu_weights.size());
    }
    for (size_t i = 0; i < static_cast<size_t>(num_class); ++i) {
      for (size_t j = 0; j < static_cast<size_t>(num_class); ++j) {
        if (i == j) {
          auc_mu_weights_matrix[i][j] = 0;
          if (std::fabs(auc_mu_weights[i * num_class + j]) > kZeroThreshold) {
            Log::Info("AUC-mu matrix must have zeros on diagonal. Overwriting value in position %d of auc_mu_weights with 0.", i * num_class + j);
          }
        } else {
          if (std::fabs(auc_mu_weights[i * num_class + j]) < kZeroThreshold) {
            Log::Fatal("AUC-mu matrix must have non-zero values for non-diagonal entries. Found zero value in position %d of auc_mu_weights.", i * num_class + j);
          }
          auc_mu_weights_matrix[i][j] = auc_mu_weights[i * num_class + j];
        }
      }
    }
  }
}

void Config::Set(const std::unordered_map<std::string, std::string>& params) {
  // generate seeds by seed.
  if (GetInt(params, "seed", &seed)) {
    Random rand(seed);
    int int_max = std::numeric_limits<int16_t>::max();
    data_random_seed = static_cast<int>(rand.NextShort(0, int_max));
    bagging_seed = static_cast<int>(rand.NextShort(0, int_max));
    drop_seed = static_cast<int>(rand.NextShort(0, int_max));
    feature_fraction_seed = static_cast<int>(rand.NextShort(0, int_max));
    objective_seed = static_cast<int>(rand.NextShort(0, int_max));
  }

  GetTaskType(params, &task);
  GetBoostingType(params, &boosting);
  GetMetricType(params, &metric);
  GetObjectiveType(params, &objective);
  GetDeviceType(params, &device_type);
  GetTreeLearnerType(params, &tree_learner);

  GetMembersFromString(params);

  GetAucMuWeights();

  // sort eval_at
  std::sort(eval_at.begin(), eval_at.end());

  if (valid_data_initscores.size() == 0 && valid.size() > 0) {
    valid_data_initscores = std::vector<std::string>(valid.size(), "");
  }
  CHECK(valid.size() == valid_data_initscores.size());

  if (valid_data_initscores.empty()) {
    std::vector<std::string> new_valid;
    for (size_t i = 0; i < valid.size(); ++i) {
      if (valid[i] != data) {
        // Only push the non-training data
        new_valid.push_back(valid[i]);
      } else {
        is_provide_training_metric = true;
      }
    }
    valid = new_valid;
  }

  // check for conflicts
  CheckParamConflict();

  if (verbosity == 1) {
    LightGBM::Log::ResetLogLevel(LightGBM::LogLevel::Info);
  } else if (verbosity == 0) {
    LightGBM::Log::ResetLogLevel(LightGBM::LogLevel::Warning);
  } else if (verbosity >= 2) {
    LightGBM::Log::ResetLogLevel(LightGBM::LogLevel::Debug);
  } else {
    LightGBM::Log::ResetLogLevel(LightGBM::LogLevel::Fatal);
  }
}

bool CheckMultiClassObjective(const std::string& objective) {
  return (objective == std::string("multiclass") || objective == std::string("multiclassova"));
}

void Config::CheckParamConflict() {
  // check if objective, metric, and num_class match
  int num_class_check = num_class;
  bool objective_type_multiclass = CheckMultiClassObjective(objective) || (objective == std::string("custom") && num_class_check > 1);

  if (objective_type_multiclass) {
    if (num_class_check <= 1) {
      Log::Fatal("Number of classes should be specified and greater than 1 for multiclass training");
    }
  } else {
    if (task == TaskType::kTrain && num_class_check != 1) {
      Log::Fatal("Number of classes must be 1 for non-multiclass training");
    }
  }
  for (std::string metric_type : metric) {
    bool metric_type_multiclass = (CheckMultiClassObjective(metric_type)
                                   || metric_type == std::string("multi_logloss")
                                   || metric_type == std::string("multi_error")
                                   || metric_type == std::string("auc_mu")
                                   || (metric_type == std::string("custom") && num_class_check > 1));
    if ((objective_type_multiclass && !metric_type_multiclass)
        || (!objective_type_multiclass && metric_type_multiclass)) {
      Log::Fatal("Multiclass objective and metrics don't match");
    }
  }

  if (num_machines > 1) {
    is_parallel = true;
  } else {
    is_parallel = false;
    tree_learner = "serial";
  }

  bool is_single_tree_learner = tree_learner == std::string("serial");

  if (is_single_tree_learner) {
    is_parallel = false;
    num_machines = 1;
  }

  if (is_single_tree_learner || tree_learner == std::string("feature")) {
    is_parallel_find_bin = false;
  } else if (tree_learner == std::string("data")
             || tree_learner == std::string("voting")) {
    is_parallel_find_bin = true;
    if (histogram_pool_size >= 0
        && tree_learner == std::string("data")) {
      Log::Warning("Histogram LRU queue was enabled (histogram_pool_size=%f).\n"
                   "Will disable this to reduce communication costs",
                   histogram_pool_size);
      // Change pool size to -1 (no limit) when using data parallel to reduce communication costs
      histogram_pool_size = -1;
    }
  }
  // Check max_depth and num_leaves
  if (max_depth > 0) {
    double full_num_leaves = std::pow(2, max_depth);
    if (full_num_leaves > num_leaves
        && num_leaves == kDefaultNumLeaves) {
      Log::Warning("Accuracy may be bad since you didn't set num_leaves and 2^max_depth > num_leaves");
    }

    if (full_num_leaves < num_leaves) {
      // Fits in an int, and is more restrictive than the current num_leaves
      num_leaves = static_cast<int>(full_num_leaves);
    }
  }
  // force col-wise for gpu
  if (device_type == std::string("gpu")) {
    force_col_wise = true;
    force_row_wise = false;
  }
}

std::string Config::ToString() const {
  std::stringstream str_buf;
  str_buf << "[boosting: " << boosting << "]\n";
  str_buf << "[objective: " << objective << "]\n";
  str_buf << "[metric: " << Common::Join(metric, ",") << "]\n";
  str_buf << "[tree_learner: " << tree_learner << "]\n";
  str_buf << "[device_type: " << device_type << "]\n";
  str_buf << SaveMembersToString();
  return str_buf.str();
}

std::string Config::ToJSON() const {
  std::stringstream str_buf;
  str_buf << "{\n";
  str_buf << R"("boosting": ")" << boosting << "\",\n";
  str_buf << R"("objective": ")" << objective << "\",\n";
  str_buf << R"("metric": )" << Common::JoinJSON(metric) << ",\n"; // vector string
  str_buf << R"("tree_learner": ")" << tree_learner << "\",\n";
  str_buf << R"("device_type": ")" << device_type << "\",\n";

  str_buf << R"("data": ")" << data << "\",\n";
  str_buf << R"("valid": )" << Common::JoinJSON(valid) << ",\n"; // vector string
  str_buf << R"("num_iterations": )" << num_iterations << ",\n";
  str_buf << R"("learning_rate": )" << learning_rate << ",\n";
  str_buf << R"("num_leaves": )" << num_leaves << ",\n";
  str_buf << R"("num_threads": )" << num_threads << ",\n";
  str_buf << R"("force_col_wise": )" << ( force_col_wise ? "true" : "false" ) << ",\n";
  str_buf << R"("force_row_wise": )" << ( force_row_wise ? "true" : "false" ) << ",\n";
  str_buf << R"("max_depth": )" << max_depth << ",\n";
  str_buf << R"("min_data_in_leaf": )" << min_data_in_leaf << ",\n";
  str_buf << R"("min_sum_hessian_in_leaf": )" << min_sum_hessian_in_leaf << ",\n";
  str_buf << R"("bagging_fraction": )" << bagging_fraction << ",\n";
  str_buf << R"("pos_bagging_fraction": )" << pos_bagging_fraction << ",\n";
  str_buf << R"("neg_bagging_fraction": )" << neg_bagging_fraction << ",\n";
  str_buf << R"("bagging_freq": )" << bagging_freq << ",\n";
  str_buf << R"("bagging_seed": )" << bagging_seed << ",\n";
  str_buf << R"("feature_fraction": )" << feature_fraction << ",\n";
  str_buf << R"("feature_fraction_bynode": )" << feature_fraction_bynode << ",\n";
  str_buf << R"("feature_fraction_seed": )" << feature_fraction_seed << ",\n";
  str_buf << R"("early_stopping_round": )" << early_stopping_round << ",\n";
  str_buf << R"("first_metric_only": )" << ( first_metric_only ? "true" : "false" ) << ",\n";
  str_buf << R"("max_delta_step": )" << max_delta_step << ",\n";
  str_buf << R"("lambda_l1": )" << lambda_l1 << ",\n";
  str_buf << R"("lambda_l2": )" << lambda_l2 << ",\n";
  str_buf << R"("min_gain_to_split": )" << min_gain_to_split << ",\n";
  str_buf << R"("drop_rate": )" << drop_rate << ",\n";
  str_buf << R"("max_drop": )" << max_drop << ",\n";
  str_buf << R"("skip_drop": )" << skip_drop << ",\n";
  str_buf << R"("xgboost_dart_mode": )" << ( xgboost_dart_mode ? "true" : "false" ) << ",\n";
  str_buf << R"("uniform_drop": )" << ( uniform_drop ? "true" : "false" ) << ",\n";
  str_buf << R"("drop_seed": )" << drop_seed << ",\n";
  str_buf << R"("top_rate": )" << top_rate << ",\n";
  str_buf << R"("other_rate": )" << other_rate << ",\n";
  str_buf << R"("min_data_per_group": )" << min_data_per_group << ",\n";
  str_buf << R"("max_cat_threshold": )" << max_cat_threshold << ",\n";
  str_buf << R"("cat_l2": )" << cat_l2 << ",\n";
  str_buf << R"("cat_smooth": )" << cat_smooth << ",\n";
  str_buf << R"("max_cat_to_onehot": )" << max_cat_to_onehot << ",\n";
  str_buf << R"("top_k": )" << top_k << ",\n";
  str_buf << R"("monotone_constraints": )" << Common::JoinJSON(monotone_constraints) << ",\n"; // vector int8
  str_buf << R"("feature_contri": )" << Common::JoinJSON(feature_contri) << ",\n"; // vector double
  str_buf << R"("forcedsplits_filename": ")" << forcedsplits_filename << "\",\n";
  str_buf << R"("forcedbins_filename": ")" << forcedbins_filename << "\",\n";
  str_buf << R"("refit_decay_rate": )" << refit_decay_rate << ",\n";
  str_buf << R"("cegb_tradeoff": )" << cegb_tradeoff << ",\n";
  str_buf << R"("cegb_penalty_split": )" << cegb_penalty_split << ",\n";
  str_buf << R"("cegb_penalty_feature_lazy": )" << Common::JoinJSON(cegb_penalty_feature_lazy) << ",\n"; // vector double
  str_buf << R"("cegb_penalty_feature_coupled": )" << Common::JoinJSON(cegb_penalty_feature_coupled) << ",\n"; // vector double
  str_buf << R"("verbosity": )" << verbosity << ",\n";
  str_buf << R"("max_bin": )" << max_bin << ",\n";
  str_buf << R"("max_bin_by_feature": )" << Common::JoinJSON(max_bin_by_feature) << ",\n"; // vector int
  str_buf << R"("min_data_in_bin": )" << min_data_in_bin << ",\n";
  str_buf << R"("bin_construct_sample_cnt": )" << bin_construct_sample_cnt << ",\n";
  str_buf << R"("histogram_pool_size": )" << histogram_pool_size << ",\n";
  str_buf << R"("data_random_seed": )" << data_random_seed << ",\n";
  str_buf << R"("output_model": ")" << output_model << "\",\n";
  str_buf << R"("snapshot_freq": )" << snapshot_freq << ",\n";
  str_buf << R"("input_model": ")" << input_model << "\",\n";
  str_buf << R"("output_result": ")" << output_result << "\",\n";
  str_buf << R"("initscore_filename": ")" << initscore_filename << "\",\n";
  str_buf << R"("valid_data_initscores": )" << Common::JoinJSON(valid_data_initscores) << ",\n"; // vector string
  str_buf << R"("pre_partition": )" << ( pre_partition ? "true" : "false" ) << ",\n";
  str_buf << R"("enable_bundle": )" << ( enable_bundle ? "true" : "false" ) << ",\n";
  str_buf << R"("is_enable_sparse": )" << ( is_enable_sparse ? "true" : "false" ) << ",\n";
  str_buf << R"("use_missing": )" << ( use_missing ? "true" : "false" ) << ",\n";
  str_buf << R"("zero_as_missing": )" << ( zero_as_missing ? "true" : "false" ) << ",\n";
  str_buf << R"("two_round": )" << ( two_round ? "true" : "false" ) << ",\n";
  str_buf << R"("save_binary": )" << ( save_binary ? "true" : "false" ) << ",\n";
  str_buf << R"("header": )" << ( header ? "true" : "false" ) << ",\n";
  str_buf << R"("label_column": ")" << label_column << "\",\n";
  str_buf << R"("weight_column": ")" << weight_column << "\",\n";
  str_buf << R"("group_column": ")" << group_column << "\",\n";
  str_buf << R"("ignore_column": ")" << ignore_column << "\",\n";
  str_buf << R"("categorical_feature": ")" << categorical_feature << "\",\n";
  str_buf << R"("predict_raw_score": )" << ( predict_raw_score ? "true" : "false" ) << ",\n";
  str_buf << R"("predict_leaf_index": )" << ( predict_leaf_index ? "true" : "false" ) << ",\n";
  str_buf << R"("predict_contrib": )" << ( predict_contrib ? "true" : "false" ) << ",\n";
  str_buf << R"("num_iteration_predict": )" << num_iteration_predict << ",\n";
  str_buf << R"("pred_early_stop": )" << ( pred_early_stop ? "true" : "false" ) << ",\n";
  str_buf << R"("pred_early_stop_freq": )" << pred_early_stop_freq << ",\n";
  str_buf << R"("pred_early_stop_margin": )" << pred_early_stop_margin << ",\n";
  str_buf << R"("predict_disable_shape_check": )" << ( predict_disable_shape_check ? "true" : "false" ) << ",\n";
  str_buf << R"("convert_model_language": ")" << convert_model_language << "\",\n";
  str_buf << R"("convert_model": ")" << convert_model << "\",\n";
  str_buf << R"("num_class": )" << num_class << ",\n";
  str_buf << R"("is_unbalance": )" << ( is_unbalance ? "true" : "false" ) << ",\n";
  str_buf << R"("scale_pos_weight": )" << scale_pos_weight << ",\n";
  str_buf << R"("sigmoid": )" << sigmoid << ",\n";
  str_buf << R"("boost_from_average": )" << ( boost_from_average ? "true" : "false" ) << ",\n";
  str_buf << R"("reg_sqrt": )" << ( reg_sqrt ? "true" : "false" ) << ",\n";
  str_buf << R"("alpha": )" << alpha << ",\n";
  str_buf << R"("fair_c": )" << fair_c << ",\n";
  str_buf << R"("poisson_max_delta_step": )" << poisson_max_delta_step << ",\n";
  str_buf << R"("tweedie_variance_power": )" << tweedie_variance_power << ",\n";
  str_buf << R"("max_position": )" << max_position << ",\n";
  str_buf << R"("lambdamart_norm": )" << ( lambdamart_norm ? "true" : "false" ) << ",\n";
  str_buf << R"("label_gain": )" << Common::JoinJSON(label_gain) << ",\n"; // vector double
  str_buf << R"("objective_seed": )" << objective_seed << ",\n";
  str_buf << R"("metric_freq": )" << metric_freq << ",\n";
  str_buf << R"("is_provide_training_metric": )" << ( is_provide_training_metric ? "true" : "false" ) << ",\n";
  str_buf << R"("eval_at": )" << Common::JoinJSON(eval_at) << ",\n"; // vector int
  str_buf << R"("multi_error_top_k": )" << multi_error_top_k << ",\n";
  str_buf << R"("auc_mu_weights": )" << Common::JoinJSON(auc_mu_weights) << ",\n"; // vector double
  str_buf << R"("num_machines": )" << num_machines << ",\n";
  str_buf << R"("local_listen_port": )" << local_listen_port << ",\n";
  str_buf << R"("time_out": )" << time_out << ",\n";
  str_buf << R"("machine_list_filename": ")" << machine_list_filename << "\",\n";
  str_buf << R"("machines": ")" << machines << "\",\n";
  str_buf << R"("gpu_platform_id": )" << gpu_platform_id << ",\n";
  str_buf << R"("gpu_device_id": )" << gpu_device_id << ",\n";
  str_buf << R"("gpu_use_dp": )" << ( gpu_use_dp ? "true" : "false" ) << "\n";

  str_buf << "}\n";
  return str_buf.str();
}

}  // namespace LightGBM

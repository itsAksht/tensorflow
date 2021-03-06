/* Copyright 2019 The TensorFlow Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
==============================================================================*/

#include "tensorflow/lite/delegates/gpu/metal/kernels/add.h"

#import <XCTest/XCTest.h>

#include <string>
#include <vector>

#include "tensorflow/lite/delegates/gpu/common/operations.h"
#include "tensorflow/lite/delegates/gpu/common/shape.h"
#include "tensorflow/lite/delegates/gpu/common/status.h"
#include "tensorflow/lite/delegates/gpu/common/tensor.h"
#include "tensorflow/lite/delegates/gpu/common/util.h"
#include "tensorflow/lite/delegates/gpu/metal/compute_task_descriptor.h"
#include "tensorflow/lite/delegates/gpu/metal/kernels/test_util.h"
#include "tensorflow/lite/delegates/gpu/common/tasks/add_test_util.h"

using ::tflite::gpu::ElementwiseAttributes;
using ::tflite::gpu::BHWC;
using ::tflite::gpu::DataType;
using ::tflite::gpu::Linear;
using ::tflite::gpu::OperationType;
using ::tflite::gpu::Tensor;
using ::tflite::gpu::TensorRef;
using ::tflite::gpu::metal::CompareVectors;
using ::tflite::gpu::metal::SingleOpModel;

@interface AddTest : XCTestCase
@end

@implementation AddTest
- (void)setUp {
  [super setUp];
}

- (void)testThreeInputTensorsOfTheSameShape {
  TensorRef<BHWC> a, b, c, output;
  a.type = DataType::FLOAT32;
  a.ref = 0;
  a.shape = BHWC(1, 2, 2, 1);

  b.type = DataType::FLOAT32;
  b.ref = 1;
  b.shape = BHWC(1, 2, 2, 1);

  c.type = DataType::FLOAT32;
  c.ref = 2;
  c.shape = BHWC(1, 2, 2, 1);

  output.type = DataType::FLOAT32;
  output.ref = 3;
  output.shape = BHWC(1, 2, 2, 1);

  ElementwiseAttributes attr;
  SingleOpModel model({ToString(OperationType::ADD), std::move(attr)}, {a, b, c}, {output});
  XCTAssertTrue(model.PopulateTensor(0, {-2.0, 0.2, 0.7, 0.8}));
  XCTAssertTrue(model.PopulateTensor(1, {0.1, 0.2, 0.3, 0.5}));
  XCTAssertTrue(model.PopulateTensor(2, {2.1, 1.2, 3.3, 4.5}));
  auto status = model.Invoke();
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
  status = CompareVectors({0.2, 1.6, 4.3, 5.8}, model.GetOutput(0), 1e-6f);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

- (void)testInputTensorAndScalar {
  ElementwiseAttributes attr;
  attr.param = 0.1f;
  TensorRef<BHWC> input, output;
  input.type = DataType::FLOAT32;
  input.ref = 0;
  input.shape = BHWC(1, 3, 1, 2);

  output.type = DataType::FLOAT32;
  output.ref = 1;
  output.shape = BHWC(1, 3, 1, 2);

  SingleOpModel model({ToString(OperationType::ADD), std::move(attr)}, {input}, {output});
  XCTAssertTrue(model.PopulateTensor(0, {-2.0, 0.2, 0.7, 0.8, 1.1, 2.0}));
  auto status = model.Invoke();
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
  status = CompareVectors({-1.9, 0.3, 0.8, 0.9, 1.2, 2.1}, model.GetOutput(0), 1e-6f);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

- (void)testInputTensorWithConstantBroadcast {
  TensorRef<BHWC> input;
  input.type = DataType::FLOAT32;
  input.ref = 0;
  input.shape = BHWC(1, 2, 2, 2);

  ElementwiseAttributes attr;
  Tensor<Linear, DataType::FLOAT32> tensor;
  tensor.shape.v = 2;
  tensor.id = 1;
  tensor.data.push_back(10.0);
  tensor.data.push_back(20.0);
  attr.param = std::move(tensor);

  TensorRef<BHWC> output;
  output.type = DataType::FLOAT32;
  output.ref = 2;
  output.shape = BHWC(1, 2, 2, 2);

  SingleOpModel model({ToString(OperationType::ADD), std::move(attr)}, {input}, {output});
  XCTAssertTrue(model.PopulateTensor(0, {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0}));
  auto status = model.Invoke();
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
  status =
      CompareVectors({11.0, 22.0, 13.0, 24.0, 15.0, 26.0, 17.0, 28.0}, model.GetOutput(0), 1e-6f);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

- (void)testAddTwoEqualTensors {
  tflite::gpu::metal::MetalExecutionEnvironment exec_env_;
  auto status = AddTwoEqualTensorsTest(&exec_env_);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

- (void)testAddFirstTensorHasMoreChannelsThanSecond {
  tflite::gpu::metal::MetalExecutionEnvironment exec_env_;
  auto status = AddFirstTensorHasMoreChannelsThanSecondTest(&exec_env_);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

- (void)testAddFirstTensorHasLessChannelsThanSecond {
  tflite::gpu::metal::MetalExecutionEnvironment exec_env_;
  auto status = AddFirstTensorHasLessChannelsThanSecond(&exec_env_);
  XCTAssertTrue(status.ok(), @"%s", std::string(status.message()).c_str());
}

@end

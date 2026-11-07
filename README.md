# Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Verification](#verification)
- [Result](#result)
- [Issues & Solutions](#issues--solutions)
- [상세 설계 과정](#상세-설계-과정)
  
# Overview
MLP 기반 MNIST 가속기를 분석하고 뉴런 단위로 연산하던 Fully Connected 구조를 4x4 Systolic Array 구조로 재설계하여 이미지 4개를 동시에 추론하도록 했습니다. 모듈 단위 Testbench로 각 모듈을 검증한 뒤 integrate하여 Layer별 연산 결과와 최종 추론 결과를 Reference Model과 비교해 일치 여부를 확인했습니다. 그 결과 추론 정확도를 동일하게 91%를 유지하면서 LUT 45%, 전력 27%를 줄었지만 추론 시간이 1.9배 늘어나는 결과를 얻어 자원 효율과 성능 간의 Trade-off를 분석했습니다.

<img width="800" height="500" alt="image" src="https://github.com/user-attachments/assets/d0e21684-82b0-4321-96dc-425342c601a3" />

## 주요 설계 및 검증 내용
- Reference RTL의 Architecture와 Dataflow를 분석하고 각 모듈의 입출력을 재정의하여 Systolic Array 기반 구조로 재구성
- 4x4 Systolic Array, 입력 Skew를 위한 Pipeline Register, Global Buffer, Weight/Bias Bank, FSM, ReLU, MaxFinder 설계
- Systolic Array, Controller, ReLU 등 모듈별 Testbench로 Reference 계산값과 비교하는 단위 검증
- Layer별 누산값, 출력값, Systolic Array 입력 데이터를 로그와 CSV 파일로 Monitoring하여 Reference와 비교하며 RTL 디버깅
- Test data 추론 결과를 Reference와 비교하는 Testbench를 통해 추론 Accuracy와 숫자별 Fail 분포 분석

## Language and Tools
- Language: Verilog, SystemVerilog
- Tools: Vivado 23.02

# Architecture
<img width="1280" height="720" alt="Reference" src="https://github.com/user-attachments/assets/02894c73-305f-49a4-801a-a57fe85eb9c0" />
<img width="1280" height="720" alt="Proposed" src="https://github.com/user-attachments/assets/0d64da34-57a5-4660-b687-4c006ee6916f" />




| 모듈 | 역할 |
|------|------|
| Systolic Array (4x4) | Activation은 행 방향, Weight는 열 방향으로 shift하며 PE에서 MAC 연산. 4개 이미지 x 4개 뉴런을 동시에 연산 |
| Global Buffer | Layer 연산 결과를 저장하고 다음 Layer의 Activation으로 공급. 64x8 메모리 4개로 구성해 cycle당 4개 데이터 입출력 |
| Weight Bank / Bias Bank | mif 파일로부터 Weight, Bias를 읽어 연산에 공급 |
| ReLU | Bias 덧셈, ReLU, Shift 기반 Quantization 및 Saturation 수행 |
| MaxFinder | 출력층 10개 뉴런 중 최댓값의 인덱스를 찾아 최종 분류 결과 출력 |

# Verification
| No | 대상 | 검증 내용 | 검증 방법 |
|----|------|-----------|-----------|
| 1 | Systolic Array (2x2) | Skew 입력, shift, 누산 결과가 행렬 곱 C = A x B와 일치 | Random 입력 + Reference 계산 비교 |
| 2 | Controller + Systolic Array | FSM(IDLE, RUN, DONE) 동작과 Skew 입력 후 연산 결과 일치 | Random 입력 + Reference 계산 비교 |
| 3 | ReLU | Bias 덧셈 후 음수는 0, 양수는 그대로 출력 | Reference 계산 비교 | 
| 4 | MaxFinder | 출력층 값 중 최댓값의 인덱스를 정확히 출력 | Directed Test | 
| 5 | Layer 연산 | Layer별 누산값과 출력값이 Reference와 일치 | 로그, CSV Monitoring 후 Reference 비교 | 
| 6 | 전체 추론 | Test data 추론 결과가 Reference 모델 결과와 일치 | Pass/Fail CSV 비교 | 

# Result
- Reference 모델과 동일한 추론 결과가 100% 동일한 것을 확인

| Parameter | Reference (ZyNet) | Proposed (Systolic Array) | Diff |
|-----------|-------------------|---------------------------|------|
| System Clock | 100 MHz | 100 MHz | - |
| Inference Time | 34.92 us | 67.65 us | x1.9 |
| Model Accuracy | 91% | 91% | - |
| Power | 0.184 mW | 0.135 mW | -27% |
| LUT | 7,552 | 4,175 | -45% |
| FF | 4,208 | 2,249 | -47% |
| BRAM | 11.5 | 11.5 | - |



# Issues & Solutions

### Issue 1. Signed/Unsigned 해석 차이로 인한 Reference Mismatch
**문제 상황**

2x2 Systolic Array 데이터 검증 Testbench에서 FAIL이 발생했지만, waveform상 데이터 입력, shift, 누산은 모두 정상 동작함

**분석**

입력값을 비교한 결과 Reference에는 129로 입력된 값이 DUT에서는 -127로 해석되고 있는 것을 확인함

**원인**

Testbench는 0~255 범위의 unsigned 랜덤 값을 생성했지만, DUT는 8bit signed 연산을 수행하여 같은 bit 패턴을 서로 다른 값으로 해석함

**해결**

랜덤 값에 offset을 적용해 -128~127 범위의 signed 값을 입력하도록 수정함. 이후 Controller Testbench에서 Reference 계산이 unsigned로 수행되는 같은 유형의 문제도 $signed를 적용해 해결함

**배운 점**

 디버깅을 통해 signed 연산 처리의 문제를 파악하고 Verilog의 signed와 unsigned 데이터 해석 및 연산 방식의 차이를 이해함

### Issue 2. Reference Model과 추론 결과 불일치
**문제 상황**

4x4 Systolic Array로 확장한 뒤 Reference Model과 추론 정확도 차이가 발생함. Reference의 정확도 9%보다 2.1% 높은 11.8%로 나타남

**분석**

RTL Simulation waveform에서 데이터 입력 valid 신호와 Systolic Array 연산 enable 신호를 비교하여 마지막 데이터가 입력되고 5 cycle 뒤에 Systolic Array 연산 enable 신호가 비활성화되는 것을 확인

**원인**

마지막 데이터가 Systolic Array를 모두 통과해 연산되려면 Load 1 cycle, 입력 Pipeline 4 cycle, Systolic Array width 4 cycle로 총 9 cycle이 필요하지만 Systolic Array 연산 enable 신호가 그 전에 꺼져 마지막 데이터 일부가 연산되지 않음

**해결**

마지막 데이터 입력 후 pe_en을 9 cycle 유지하도록 수정하여 Reference 모델과 동일한 추론 결과를 얻음

**배운 점**

Systolic Array는 입력이 끝난 뒤에도 데이터가 배열을 통과하는 latency를 고려해 enable 구간을 설계해야 함. 또한 정확도 같은 결과 지표의 차이도 waveform 분석을 통해 RTL 타이밍 문제로 원인을 좁힐 수 있다는 것을 깨달음

### Issue 3. Layer 출력값이 Reference와 불일치 (Quantization Scaling)
**문제 상황**

주변 모듈을 통합한 뒤 추론 결과가 Reference와 다르게 출력됨

**분석**

$display로 Layer 1의 뉴런 0~3 누산 로그와 Layer 1 출력값을 Reference와 비교한 결과 누산값은 일치하지만 ReLU와 Scaling 이후 값이 달라지는 것을 확인. 이후 Test data 1000개의 추론 결과를 CSV로 저장하여 Shift 값에 따른 추론 정확도가(Shift 4: 11.8%, Shift 5: 14.1%)인 것을 확인

**원인**

처음에는 누산 결과의 상위 8bit만 취해 데이터 정보가 손실됨. 이후 Shift 방식으로 바꿨지만 Activation 포맷을 Q2.6으로 잘못 해석해 Shift 값을 5로 설정함. MNIST 입력 범위를 고려하면 Activation은 Q1.7, Weight는 Q4.4이므로 누산 결과는 Q5.11인 것을 확인

**해결**

Q5.11 누산 결과를 4bit 산술 Shift하여 8bit로 변환하고 표현 범위를 넘는 값은 127로 Saturation하도록 ReLU 모듈에서 함께 처리함

**배운 점**

Fixed-point 연산에서는 각 데이터의 Q format을 정확히 해석해야 정보 손실 없이 Quantization할 수 있다는 것을 깨달음

# 상세 설계 과정
설계 및 디버깅 과정은 블로그에 정리했습니다.
https://blog.naver.com/PostList.naver?from=postList&blogId=cho12555&categoryNo=1&currentPage=1

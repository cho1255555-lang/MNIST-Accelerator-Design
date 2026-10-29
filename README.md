# Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Verification](#verification)
- [Result](#result)
- [Issues & Solutions](#issues--solutions)
- [상세 설계 과정](#상세-설계-과정)
  
# Overview
MLP 기반 MNIST 가속기를 분석하던 Fully Connected 구조를 4x4 Systolic Array 구조로 재설계하여 이미지 4개를 동시에 추론하도록 했습니다. 모듈 단위 Testbench로 각 모듈을 검증한 뒤 integrate하여 Layer별 연산 결과와 최종 추론 결과를 Reference Model과 비교해 일치 여부를 확인했습니다. 그 결과 추론 정확도를 동일하게 91%를 유지하면서 LUT 45%, 전력 27%를 줄였지만 추론 시간이 1.9배 늘어나는 결과를 얻어 자원 효율과 성능 간의 Trade-off를 경험했습니다.

<img width="800" height="500" alt="image" src="https://github.com/user-attachments/assets/d0e21684-82b0-4321-96dc-425342c601a3" />

## 주요 설계 및 검증 내용
- Reference RTL의 Architecture와 Dataflow를 분석하고 각 모듈의 입출력을 재정의하여 Systolic Array 기반 구조로 재구성
- 4x4 Systolic Array, Pipeline Register, Global Buffer, Weight/Bias Bank, ReLU, MaxFinder 설계
- Systolic Array, Controller, ReLU 등 모듈별로 Testbench를 작성하여 예상값과 모듈 출력을 비교하는 Self-Checking Testbench 구축 
- Layer별 누산값, 출력값, Systolic Array 입력 데이터를 로그와 CSV 파일로 Monitoring하여 Reference와 비교 검증

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



### Issue 1. Reference Model과 추론 결과 불일치 (latency 계산 오류)
**문제 상황**

1000개 sample을 Proposed Model과 Reference Model에 입력하여 error rate 비교 결과 

- **Proposed Model** : 11.8%
- **Reference Model** : 9%

Proposed Model이 Reference Model보다 error rate가 2.8% 더 높게 나타남

**분석**

Reference Model과 비교하여 추론 결과가 맞지 않았던 추론 과정을 RTL Simulation waveform을 통해 집중적으로 추적

**원인**
데이터 입력 valid 신호와 Systolic Array 연산 enable 신호를 비교하여 마지막 데이터가 입력되고 5 cycle 뒤에 Systolic Array 연산 enable 신호가 비활성화되는 것을 확인

마지막 데이터가 Systolic Array를 모두 통과해 연산되려면 Load 1 cycle, 입력 Pipeline 4 cycle, Systolic Array width 4 cycle로 총 9 cycle이 필요하지만 Systolic Array 연산 enable 신호가 그 전에 꺼져 마지막 데이터 일부가 연산되지 않음

**해결**

마지막 데이터 입력 후 pe_en(연산 enable신호)을 9 cycle 유지하도록 수정하여 Reference 모델과 동일한 추론 결과를 얻음

**배운 점**

Systolic Array는 입력이 끝난 뒤에도 데이터가 배열을 통과하는 latency를 고려해 enable 구간을 설계해야 함. 또한 정확도 같은 결과 지표의 차이도 waveform 분석을 통해 RTL 타이밍 문제로 원인을 좁힐 수 있다는 것을 깨달음

### Issue 2. Layer 출력값 Reference와 불일치 (Scaling 설계 오류)
**문제 상황**

개별 모듈 검증을 모두 완료한 뒤 통합하여 MNIST 1개 Sample을 추론했으나, 추론 결과가 정답과 일치하지 않는 Fail 발생

**분석**

누산 결과를 $display로 출력해 확인한 결과 Layer 1 뉴런의 누산 결과는 같았지만 ReLU와 Scaling을 거친 Layer 2의 입력이 다르다는 것을 확인

**원인**

누산 결과에 대해 별도의 처리 없이 상위 8bit만 bit slicing하는 방식으로 Scaling을 설계

**해결**

학습 코드에서 Activation과 Weight의 비트 형식을 확인하여 각각 Q1.7, Q4.4이고 곱셈 결과는 Q5.11 구조임을 파악함

이에 따라 누산 결과를 4bit 산술 Shift한 뒤 하위 8bit를 취하는 방식으로 Scaling을 변경

**배운 점**

Fixed-point 연산을 이해하는 계기가 되었고, Scaling 시 소수점 위치를 고려하지 않으면 값이 잘못 해석되고 정밀도가 손실될 수 있음을 깨달음

### Issue 3. Signed/Unsigned 해석 차이로 인한 Reference Mismatch
**문제 상황**

2x2 Systolic Array 데이터 검증 Testbench에서 FAIL이 발생했지만, waveform상 데이터 입력, shift, 누산은 모두 정상 동작함

**분석**

입력값을 비교한 결과 Reference에는 129로 입력된 값이 DUT에서는 -127로 해석되고 있는 것을 확인함

**원인**

Testbench는 0~255 범위의 unsigned 랜덤 값을 생성했지만, DUT는 8bit signed 연산을 수행하여 같은 bit 패턴을 서로 다른 값으로 해석함

**해결**

랜덤으로 생성한 0\~255 값에 -128의 offset을 적용하여 -128\~127 범위의 signed 값을 입력하도록 수정

**배운 점**

디버깅을 통해 signed와 unsigned에 따라 다른 값으로 해석된다는 것을 확인했고 Verilog의 signed와 unsigned 데이터 해석 및 연산 방식의 차이를 이해함

# 상세 설계 과정
설계 및 디버깅 과정은 블로그에 정리했습니다.
https://blog.naver.com/PostList.naver?from=postList&blogId=cho12555&categoryNo=1&currentPage=1

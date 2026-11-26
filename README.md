# Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Verification](#verification)
- [Result](#result)
- [Issues & Solutions](#issues--solutions)
- [상세 설계 과정](#상세-설계-과정)
  
# Overview
기존 MLP 기반 MNIST 가속기의 Fully Connected 구조를 분석하고, PE를 재사용하는 4×4 Systolic Array 구조로 재설계한 프로젝트입니다. 기존 RTL의 Architecture와 Dataflow를 분석하여 연산 구조, 데이터 경로 및 제어 구조를 재구성했으며 모듈 단위부터 전체 추론까지 Self-Checking Testbench를 구축하여 설계와 검증을 수행했습니다.

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
| Systolic Array (4x4) | Activation은 행 방향, Weight는 열 방향으로 shift하며 PE에서 MAC 연산 |
| Global Buffer | Layer 연산 결과를 저장하고 다음 Layer의 Activation으로 공급. 64x8 메모리 4개로 구성해 cycle당 4개 데이터 입출력 |
| Weight Bank / Bias Bank | mif 파일로부터 Weight, Bias를 읽어 연산에 공급 |
| ReLU | Bias 덧셈, ReLU, Shift 기반 Requantization 수행 |
| MaxFinder | 출력층 10개 뉴런 중 최댓값의 인덱스를 찾아 최종 분류 결과 출력 |

# Verification
| No | 대상 | 검증 내용 | 검증 방법 |
|----|------|-----------|-----------|
| 1 | Systolic Array | Skew 입력, shift, 누산 결과가 행렬 곱 C = A x B와 일치 | Random 입력 + Expected Value 비교 (Self-Checking) |
| 2 | Controller + Systolic Array | FSM(IDLE, RUN, DONE) 동작과 Skew 입력 후 연산 결과 일치 | Random 입력 + Expected Value 비교 (Self-Checking) |
| 3 | ReLU | Bias 덧셈 후 음수는 0, 양수는 그대로 출력 | Random 입력 + Expected Value 비교 (Self-Checking) | 
| 4 | MaxFinder | 출력층 값 중 최댓값의 인덱스를 정확히 출력 | Directed Test | 
| 5 | Layer 연산 | Layer별 누산값과 출력값이 Reference와 일치 | sample 입력 + layer별 Expected Value 비교 (Self-Checking)  | 
| 6 | TOP | Test data 추론 결과가 Reference 모델 결과와 일치 | 추론 결과 CSV 파일로 기록 후 Zynet의 추론 결과와 비교 | 

# Result
- Reference 모델과 동일한 추론 결과가 100% 동일한 것을 확인

| Parameter | Reference (ZyNet) | Proposed (Systolic Array) | Diff |
|-----------|-------------------|---------------------------|------|
| System Clock | 100 MHz | 100 MHz | - |
| Inference Time | 34.92 us | 67.65 us | x1.9 |
| Model Accuracy | 91% | 91% | - |
| Power | 0.184 W | 0.135 W | -27% |
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

Systolic Array는 입력이 끝난 뒤에도 데이터가 배열을 통과하는 latency를 고려해 enable 구간을 설계해야 함. 또한 정확도 같은 결과 지표의 차이도 waveform 분석을 통해 RTL 타이밍 문제로 원인을 좁힐 수 있다는 것을 깨닫게 됨

### Issue 2. Layer 출력값 불일치 (Scaling 설계 오류)
**문제 상황**

개별 모듈 검증을 완료한 뒤 통합하여 MNIST Sample 1개를 추론한 결과 Expected Value와 일치하지 않는 FAIL 발생

**분석**

각 Layer의 출력을 $display로 출력해 확인한 결과 Layer 1의 누산값은 일치했지만 ReLU 모듈을 거친 Layer 2의 입력값이 Expected Value와 다름을 확인

**원인**

누산 결과에 대해 별도의 처리 없이 상위 8bit만 bit slicing하는 방식으로 Scaling을 설계

**해결**

학습 코드에서 Activation과 Weight의 비트 형식을 확인하여 각각 Q1.7, Q4.4이고 곱셈 결과는 Q5.11 구조임을 파악함

이에 따라 누산 결과를 4bit 산술 Shift한 뒤 하위 8bit를 취하는 방식으로 Scaling을을 변경

**배운 점**

Fixed-point 연산을 이해하는 계기가 되었고, Scaling 시 소수점 위치를 고려하지 않으면 값이 잘못 해석되고 정밀도가 손실될 수 있음을 깨닫게 됨

### Issue 3. 2×2 Systolic Array 검증 중 Expected Value 불일치 (Signed/Unsigned 해석 오류)
**문제 상황**

2x2 Systolic Array 데이터 검증 Testbench에서 FAIL이 발생했지만 waveform상 데이터 입력, data shift, 누산은 모두 정상 동작

**분석**

DUT 입력값과 Expected Value 계산에 쓰인 값을 비교한 결과 같은 비트 패턴(8'b1000_0001)이 Expected Value 계산 과정에서 129, DUT에서 -127로 연산되고 있음을 확인

**원인**

DUT는 8bit signed 연산을 수행하지만 Testbench는 변수를 signed 변수로 선언하지 않아 Expected Value 계산 과정에 unsigned 연산을 하게된 것이 원인이 됨

**해결**

랜덤으로 생성한 0\~255 값에 -128 offset을 적용해 -128\~127 범위의 signed 값으로 입력하고, Expected Value도 같은 signed 값 기준으로 계산되도록 수정

**배운 점**

데이터 형식과 연산 방식에 따라 연산 결과가 달라질 수 있다는 것을 깨닫게 됨. 이후 데이터 형식과 연산 방식을 먼저 파악하고 DUT와 Testbench에 동일한 조건을 적용하는 습관을 갖게 됨

# 상세 설계 과정
설계 및 디버깅 과정은 블로그에 기록했습니다.
https://blog.naver.com/PostList.naver?from=postList&blogId=cho12555&categoryNo=1&currentPage=1

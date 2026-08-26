# Compute 직렬 로그와 중지 전 증거 저장

Checked: 2026-08-26. Label: observed(n=1 Cloud run), 로컬 회귀검증 별도.

Phase13 builder의 Apache 설치/HTTP·reset 후새boot검사가성공하고VM을중지했다. 이후 `gcloud compute instances get-serial-port-output`은TERMINATED VM에대해`resource is not ready`로실패했다. 중지후에도같은API로제작증거를수집할수있다는가정을반박한관측이다.

공식 [직렬 로그 조회](https://docs.cloud.google.com/compute/docs/troubleshooting/viewing-serial-port-output)와 [gcloud 명령](https://docs.cloud.google.com/sdk/gcloud/reference/compute/instances/get-serial-port-output)을대조했다. 실시간조회와별도CloudLogging보존은다르다. 이번run에는추가Logging/IAM설정을만들지않는다.

보완: `phases/13/terraform/wait-builder.sh`는서로다른두boot와Apache package version·Cloud instance ID를RUNNING상태에서0600 JSON으로저장한뒤stop한다. after-apply는이receipt를읽으며API를다시호출해중지VM직렬로그를요구하지않는다. 기존run에receipt가없을때는저장계획의조건부복구action으로동일CloudID/라벨/원본disk/중지상태를확인하고기존builder만start→reset→capture→stop한다. 이미지만들기를다시하지않고재수집시점을별도로표시한다.

로컬근거: `tests/test-phases-10-15.py`의새boot없음/중지전receipt작성/기존receipt사용/타CloudID거부/재수집표시보존 검사,49회귀·Phase13 TF mock2개/fmt/validate/Bash/gate PASS. 보완후Cloud성공은실제결과기록전까지미검증이다. 최초관측run은`p13-260826-2243`,직렬원문·계정·state는Git에저장하지않는다.

한계: 원본직렬로그전체의영구보존이나모든인스턴스상태에서의조회지원주장이아니다. replay로모은readiness는원래이미지제작시각의직렬로그를복원한것이아니다. receipt와image/sourceDisk 및현재backend HTTP를분리해검증한다.

후속 observed(n=1): 2fc9f4…25no-op 재apply는exit0이었다. 기존builder만재시작/reset/중지했고Apache2.4.68-1~deb12u1/서로다른2boot와sourceDisk/instanceID를검사했다. provenance의readiness_recovered_after_image=true와receiptSHA를확인했다. 이성공은증거복구경로이며전체ALB/부하검증결과와구분한다.

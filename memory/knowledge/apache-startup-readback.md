# Apache 시작 스크립트의 설정 반영

Checked: 2026-08-26. Label: 공식 문서·로컬 회귀; 설정 재읽기 누락은 사전 추론, DirectoryIndex 누적은 실제 관측(n=1).

Debian `a2enconf`는 conf-enabled 심볼릭 링크를 만들며, 이미 실행 중인 Apache 프로세스에 설정 재읽기를 직접 요청하는 명령은 아니다. Apache restart/graceful은 설정을 다시 읽는다. 근거: [Debian a2enconf](https://manpages.debian.org/bookworm/apache2/a2enconf.8.en.html), [Apache restart](https://httpd.apache.org/docs/2.4/stopping.html).

Phase14에서 apt 설치 중 서버가 이미 시작된 뒤 DirectoryIndex를 쓰고 `enable --now`만 호출하면 기존 설정으로 계속 응답할 수 있다고 추론했다. 아직 배포하기 전 configtest→enable→restart로 보완했다. 50개 회귀의 순서 검사와 Phase14 gate/TF mock 통과. 실제 Cloud HTTP 성공 여부는 run evidence와 truth에서 별도 판정한다. 단순 port80 health만으로 PHP 페이지·client IP가 맞다고 판정하지 않고 utility VM에서 직접 backend와VIP60응답을 확인한다.

후속 실제 관측: restart를 반영한 VM에서도 직접backend/VIP의 `/`가 Apache Debian 기본페이지를반환했다. [DirectoryIndex 공식 계약](https://httpd.apache.org/docs/2.4/mod/mod_dir.html#directoryindex)은같은context의복수선언이교체가아닌누적임을명시한다. `DirectoryIndex disabled` 뒤 `DirectoryIndex index.php`를써야기존index.html우선순위가사라진다.

기존immutable template/VM교체는피하고정확한MIG member의Cloud ID/project/zone/run/phase라벨을확인한뒤post-apply에서실습Apache설정한파일만수렴시킨다. `ensure-index.sh`는configtest→reload→localhost hostname본문을검사하며반복실행해도같은결과다. 새로운clone실행도동일post-apply를거친다.54회귀의2회멱등성과외부ID SSH전거부/JSON이름추출검사,Phase14 TFmock2/gate가통과했다. 실제복구성공은아직재apply결과로판정한다.

별도CLI관측: gcloud581의MIG list-instances `--format=value(instance)`가VM이름대신zone을출력했다. 원시`--format=json`의instance URL을파싱하고project/zone/run을검증하도록수정했다. 주소표시transform을기계식ID조회로취급하지않는다. 같은run의실제출력으로확인한단일버전관측이다.

최종 observed(n=1): 기존startup이덮어쓰지않는후순위 `p14-php-index.conf`로분리한9af07d…18no-op 재apply/verify exit0. configtest/localhost본문·두backend직접HTTP·VIP60응답/marker2/clientIP보존을통과했다. 실제재부팅시험은아니며새drop-in과원래startup의서로다른경로를코드/fixture로대조했다. 원래16→18개증설뒤복구재apply의리소스교체/삭제는0이다.

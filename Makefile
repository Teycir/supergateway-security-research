.PHONY: bootstrap verify verify-fix reproduce checksums clean

bootstrap:
	./scripts/bootstrap.sh

verify:
	./pocs/verify_all.sh 1

verify-fix:
	./pocs/verify_fix.sh

reproduce:
	./scripts/reproduce.sh 1

checksums:
	./scripts/checksums.sh

clean:
	rm -rf .artifacts .work received cswsh_proof.txt

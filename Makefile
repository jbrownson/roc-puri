.PHONY: run native-run clean

run native-run:
	$(MAKE) -C todo native-run

clean:
	$(MAKE) -C geometry clean
	$(MAKE) -C roclay clean
	$(MAKE) -C puri clean
	$(MAKE) -C puri-roclay clean
	$(MAKE) -C roc-ray-platform clean
	$(MAKE) -C todo clean

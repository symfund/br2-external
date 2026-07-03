include $(sort $(wildcard $(BR2_EXTERNAL_EXTPACK_PATH)/package/*/*.mk))

.PHONY: tflite-setup-env tflite-launch-lab

define TFLITE_SETUP_ENV_CMDS
	@echo "=== Starting TensorFlow develop environment setup on Ubuntu 24.04..."
	mkdir -p $(BR2_EXTERNAL_EXTPACK_PATH)/envs
	@\
	if ! dpkg -l | grep -q "python3-venv"; then \
		echo "Installing python3-venv..."; \
		sudo apt-get update && sudo apt-get install -y python3-venv; \
	fi; \
	if ! dpkg -l | grep -q "python3-pip"; then \
		echo "Installing python3-pip..."; \
		sudo apt-get update && sudo apt-get install -y python3-pip; \
	fi; \
	echo "=== Creating virtual environment 'tf_env'"; \
	python3 -m venv $(BR2_EXTERNAL_EXTPACK_PATH)/envs/tf_env && \
	. $(BR2_EXTERNAL_EXTPACK_PATH)/envs/tf_env/bin/activate && \
	echo "Installing tensorflow and jupyter..." && \
	pip install --upgrade pip && \
	pip install --default-timeout=900 tensorflow[and-cuda] jupyter jupyterlab --retries 10 && \
	echo "=== Linking Internal Virtual Environment NVIDIA Libraries ===" && \
	pushd $$(dirname $$(python3 -c 'print(__import__("tensorflow").__file__)')) && \
	ln -svf ../nvidia/*/lib/*.so* . && \
	popd && \
	echo "=== Linking CUDA Compiler Tool (ptxas) ===" && \
	VENV_SITE_PACKAGES=$(BR2_EXTERNAL_EXTPACK_PATH)/envs/tf_env/lib/python3.12/site-packages && \
	ln -sf $$(find $$VENV_SITE_PACKAGES/nvidia -type f -name ptxas -print -quit) $(BR2_EXTERNAL_EXTPACK_PATH)/envs/tf_env/bin/ptxas && \
	echo "=== Configuring Jupyter Kernel with CUDA Paths ===" && \
	python3 -m ipykernel install --user --name=tf_env_cuda --display-name="Python 3 (TF CUDA)" && \
	KERNEL_JSON=~/.local/share/jupyter/kernels/tf_env_cuda/kernel.json && \
	python3 -c "import json; f=open('$$KERNEL_JSON','r+'); d=json.load(f); d['env']={'LD_LIBRARY_PATH': '$$VENV_SITE_PACKAGES/nvidia/cuda_runtime/lib:$$VENV_SITE_PACKAGES/nvidia/cublas/lib:$$VENV_SITE_PACKAGES/nvidia/cudnn/lib:$$VENV_SITE_PACKAGES/nvidia/cufft/lib:$$VENV_SITE_PACKAGES/nvidia/curand/lib:$$VENV_SITE_PACKAGES/nvidia/cusolver/lib:$$VENV_SITE_PACKAGES/nvidia/cusparse/lib:$$VENV_SITE_PACKAGES/nvidia/nccl/lib:$$VENV_SITE_PACKAGES/nvidia/nvjitlink/lib:/usr/lib/x86_64-linux-gnu:/usr/local/cuda/lib64'}; f.seek(0); json.dump(d,f,indent=1); f.truncate()" && \
	echo "=== Setting TF CUDA as the Default Jupyter Kernel ===" && \
	LAB_SETTINGS_DIR=~/.jupyter/lab/user-settings/@jupyterlab/notebook-extension && \
	mkdir -p "$$LAB_SETTINGS_DIR" && \
	echo '{"codeCellConfig": {"lineNumbers": true}}' > "$$LAB_SETTINGS_DIR/tracker.jupyterlab-settings" && \
	echo '{"defaultKernel": "tf_env_cuda"}' > "$$LAB_SETTINGS_DIR/factory.jupyterlab-settings" && \
	echo "Configuring Jupyter Server..." && \
	JUPYTER_CONFIG_DIR=$$(jupyter --config-dir) && \
	mkdir -p "$$JUPYTER_CONFIG_DIR" && \
	echo "c.ServerApp.ip = '0.0.0.0'" >> "$$JUPYTER_CONFIG_DIR/jupyter_server_config.py" && \
	echo "c.ServerApp.open_browser = False" >> "$$JUPYTER_CONFIG_DIR/jupyter_server_config.py" && \
	echo "c.ServerApp.token = 'tflite_secret_token'" >> "$$JUPYTER_CONFIG_DIR/jupyter_server_config.py" && \
	echo "Jupyter successfully configured." && \
	deactivate
	@echo "Setup complete. Returned to Buildroot shell."
endef

tflite-setup-env:
	$(TFLITE_SETUP_ENV_CMDS)

define TFLITE_LAUNCH_LAB_CMDS
	@echo "=== Verifying host hardware environment..."
	@\
	if ! command -v nvidia-smi &>/dev/null; then \
		echo "====================================================================="; \
		echo "⚠️  WARNING: No NVIDIA drivers found on this system (nvidia-smi missing)."; \
		echo "TensorFlow will fall back to CPU execution."; \
		echo "Fix by running: sudo apt install nvidia-driver-535 nvidia-cuda-toolkit"; \
		echo "====================================================================="; \
		read -p "Press [Enter] to continue launching on CPU anyway, or Ctrl+C to abort..." < /dev/tty; \
	elif ! nvidia-smi >/dev/null 2>&1; then \
		echo "====================================================================="; \
		echo "❌ ERROR: NVIDIA drivers are installed but broken or inaccessible."; \
		echo "Ensure your user account belongs to the 'render' or 'video' groups."; \
		echo "Try checking kernel modules: sudo modprobe nvidia"; \
		echo "====================================================================="; \
		read -p "Press [Enter] to continue launching on CPU anyway, or Ctrl+C to abort..." < /dev/tty; \
	else \
		echo "✅ Host GPU hardware verified successfully."; \
	fi
	@echo "=== Launching Jupyter Lab..."
	@\
	. $(BR2_EXTERNAL_EXTPACK_PATH)/envs/tf_env/bin/activate || { echo "Error: Environment not setup. Run 'make tflite-setup-env' first."; exit 1; } && \
	if ! command -v jupyter-lab &>/dev/null; then \
		echo "Jupyter Lab is not installed. Installing it now..."; \
		pip install jupyterlab; \
	fi && \
	read -p "Enter the full path to your jupyter notebook file or directory: " USER_PATH < /dev/tty; \
	REAL_PATH=$$(eval echo "$$USER_PATH"); \
	if [ -z "$$REAL_PATH" ]; then \
		WORKSPACE_DIR="$(BR2_EXTERNAL_EXTPACK_PATH)"; \
		TARGET_ARG=""; \
		URL_PATH="/lab"; \
		echo "No path entered. Defaulting to workspace root."; \
	elif [ -d "$$REAL_PATH" ]; then \
		WORKSPACE_DIR="$$REAL_PATH"; \
		TARGET_ARG=""; \
		URL_PATH="/lab"; \
	elif [ -f "$$REAL_PATH" ]; then \
		WORKSPACE_DIR=$$(dirname "$$REAL_PATH"); \
		TARGET_ARG="$$REAL_PATH"; \
		URL_PATH="/lab/tree/$$(basename "$$REAL_PATH")"; \
		echo "Target file: $$(basename "$$REAL_PATH") inside $$WORKSPACE_DIR"; \
	else \
		echo "Error: Path does not exist."; \
		exit 1; \
	fi; \
	echo "=== Cleaning local workspace layout cache..." && \
	rm -rf ~/.jupyter/lab/workspaces/* && \
	echo "=== Launching Jupyter Lab and Forcing Host Browser..." && \
	(sleep 3 && python3 -c "import webbrowser; webbrowser.open('http://127.0.0.1:8888' + '$$URL_PATH' + '?token=tflite_secret_token')") & \
	if [ -z "$$TARGET_ARG" ]; then \
		DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=$$DBUS_SESSION_BUS_ADDRESS jupyter lab --notebook-dir="$$WORKSPACE_DIR" --IdentityProvider.token="tflite_secret_token" --no-browser; \
	else \
		DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=$$DBUS_SESSION_BUS_ADDRESS jupyter lab --notebook-dir="$$WORKSPACE_DIR" --IdentityProvider.token="tflite_secret_token" --no-browser "$$TARGET_ARG"; \
	fi; \
	deactivate
endef

tflite-launch-lab:
	$(TFLITE_LAUNCH_LAB_CMDS)


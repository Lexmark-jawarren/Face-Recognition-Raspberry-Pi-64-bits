SKILL_NAME = face_recognition_demo
DEV_IMAGE_NAME = localhost:5000/$(SKILL_NAME):latest


VENV = venv
BIN = $(VENV)/bin
PIP = $(BIN)/pip

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
        $(error Undefined $1$(if $2, ($2))$(if $(value @), \
                required by target `$@')))


.PHONY check-dev-optra:
	@:$(call check_defined, DEV_OPTRA, Optra SN to deploy the skill to)

.PHONY: dev-ssh-tunnel
dev-ssh-tunnel: check-dev-optra
	@EXISTING_TUNNEL=$$(ps aux | grep 5000:localhost:5000 | grep -v grep); \
	if [ -z "$$EXISTING_TUNNEL" ]; then \
		ssh -N -f -R  5000:localhost:5000 root@$(DEV_OPTRA) -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o serverAliveCountMax=3; \
	fi

.PHONY: local-registry
local-registry:
	@EXISTING_REGISTRY=$$(docker ps -q -f name=registry); \
	if [ -z "$$EXISTING_REGISTRY" ]; then \
		docker run -d -p 5000:5000 --restart=always --name registry registry:2.7; \
	fi

.PHONY: dev-build
dev-build: local-registry
	docker buildx build --build-arg INSTALL_DEV_TOOLS=true --platform linux/arm64 -t $(DEV_IMAGE_NAME) .
	docker push $(DEV_IMAGE_NAME)

.PHONY: dev-pull
dev-pull: dev-ssh-tunnel local-registry check-dev-optra
	@ssh -t root@$(DEV_OPTRA) "docker pull $(DEV_IMAGE_NAME)"

.PHONY: dev-delete
dev-delete: check-dev-optra
	@ssh -t root@$(DEV_OPTRA) "docker rm -f $(SKILL_NAME)"

.PHONY: dev-create
dev-create: check-dev-optra
	@ssh -t root@$(DEV_OPTRA) "curl --unix-socket /var/run/docker.sock -X POST http://localhost/containers/create?name=$(SKILL_NAME) -H \"Content-Type: application/json\" -d '$$(cat create-options.json)'"

.PHONY: dev-start
dev-start: check-dev-optra
	@ssh -t root@$(DEV_OPTRA) "docker start $(SKILL_NAME)"

.PHONY: dev-deploy
dev-deploy: dev-ssh-tunnel local-registry dev-build dev-pull dev-delete dev-create dev-start

.PHONY: clean
clean:
	rm -rf venv
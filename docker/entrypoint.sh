#!/bin/sh

cd ${WORKDIR}
if [ "${NASTOOL_AUTO_UPDATE}" = "true" ]; then
    if [ ! -s /tmp/requirements.txt.sha256sum ]; then
        sha256sum requirements.txt > /tmp/requirements.txt.sha256sum
    fi
    if [ ! -s /tmp/third_party.txt.sha256sum ]; then
        sha256sum third_party.txt > /tmp/third_party.txt.sha256sum
    fi
    echo "更新程序..."
    git remote set-url origin "${REPO_URL}" &> /dev/null
    echo "windows/" > .gitignore

    git clean -dffx
    git fetch --depth 1 origin ${REPO_BRANCH}
    git reset --hard origin/${REPO_BRANCH}
    if [ $? -eq 0 ]; then
        echo "更新成功..."
        # Python依赖包更新
        hash_old=$(cat /tmp/requirements.txt.sha256sum)
        hash_new=$(sha256sum requirements.txt)
        if [ "${hash_old}" != "${hash_new}" ]; then
            echo "检测到requirements.txt有变化，重新安装依赖..."
            if [ "${NASTOOL_CN_UPDATE}" = "true" ]; then
                pip install --upgrade pip setuptools wheel -i "${PYPI_MIRROR}"
                pip install -r requirements.txt -i "${PYPI_MIRROR}"
            else
                pip install --upgrade pip setuptools wheel
                pip install -r requirements.txt
            fi
            if [ $? -ne 0 ]; then
                echo "无法安装依赖，请更新镜像..."
            else
                echo "依赖安装成功..."
                sha256sum requirements.txt > /tmp/requirements.txt.sha256sum
                hash_old=$(cat /tmp/third_party.txt.sha256sum)
                hash_new=$(sha256sum third_party.txt)
                if [ "${hash_old}" != "${hash_new}" ]; then
                    echo "检测到third_party.txt有变化，更新第三方组件..."
                    git submodule update --init --recursive
                    if [ $? -ne 0 ]; then
                        echo "无法更新第三方组件，请更新镜像..."
                    else
                        echo "第三方组件安装成功..."
                        sha256sum third_party.txt > /tmp/third_party.txt.sha256sum
                    fi
                fi
            fi
        fi
    else
        echo "更新失败，继续使用旧的程序来启动..."
    fi
else
    echo "程序自动升级已关闭，如需自动升级请在创建容器时设置环境变量：NASTOOL_AUTO_UPDATE=true"
fi

echo "以PUID=${PUID}，PGID=${PGID}的身份启动程序..."


mkdir -p /.local
mkdir -p /.pm2
chown -R "${PUID}":"${PGID}" "${WORKDIR}" /config /usr/lib/chromium /.local /.pm2
export PATH=${PATH}:/usr/lib/chromium

umask "${UMASK}"
exec su-exec "${PUID}":"${PGID}" "$(which dumb-init)" "$(which pm2-runtime)" start run.py -n NAStool --interpreter python3

# Kubernetes
alias k=kubectl
complete -o default -F __start_kubectl k

function ktl {
    user=ramon.trepat@bonarea.com
    case $1 in
        # ENTORN DEV
        dev) # dev proves antic
        cluster=tkc-dev-01
        tanzu_namespace=dev
        server=https://sv-k8s.bonarea.net
        ;;

        # ENTORN DEVEL
        devel)
        cluster=tkc-devel-01
        tanzu_namespace=devel
        server=https://sv-k8s.bonarea.net
        ;;
        lan-devel)
        cluster=tkc-lan-devel-01
        tanzu_namespace=lan-devel
        server=https://sv-k8s.bonarea.net
        ;;
        gray-devel)
        cluster=tkc-gray-devel-01
        tanzu_namespace=gray-devel
        server=https://sv-k8s.bonarea.net
        ;;

        # ENTORN DE PRE
        # LAN <==> GRAY
        lan-pre)
        cluster=tkc-lan-pre-01
        tanzu_namespace=lan-pre
        server=https://sv-k8s.bonarea.net
        ;;
        gray-pre)
        cluster=tkc-gray-pre-01
        tanzu_namespace=gray-pre
        server=https://sv-k8s.bonarea.net
        ;;
        
        # ENTORN DE PROD
        # LAN <==> GRAY
        lan-prod)
        cluster=tkc-lan-prod-01
        tanzu_namespace=lan-prod
        server=https://sv-k8s.bonarea.net
        ;;
        gray-prod)
        cluster=tkc-gray-prod-01
        tanzu_namespace=gray-prod
        server=https://sv-k8s.bonarea.net
        ;;

        # RANCHER (PROVISIONAL)
        rke-devel) # rancher devel
        cluster=tkc-rke-devel-01
        tanzu_namespace=rke-devel
        server=https://sv-k8s.bonarea.net
        ;;
        rke-prod) # rancher prod
        cluster=tkc-rke-prod-01
        tanzu_namespace=rke-prod
        server=https://sv-k8s.bonarea.net
        ;;
        rke-public) # rancher public
        cluster=tkc-rke-public-01
        tanzu_namespace=rke-public
        server=https://sv-k8s.bonarea.net
        ;;
    esac
    kubectl vsphere login --insecure-skip-tls-verify --tanzu-kubernetes-cluster-name $cluster  --tanzu-kubernetes-cluster-namespace $tanzu_namespace -u $user --server=$server --password=$password
}
complete -W "dev devel lan-devel gray-devel lan-pre gray-pre lan-prod gray-prod rke-devel rke-prod rke-public" ktl

function kns {
    if [[ -z "$1" ]]; then
        kubectl get ns
    else
        kubectl config set-context --current --namespace="$1"
    fi
}

function kctx {
    if [[ -z "$1" ]]; then
        kubectl config get-contexts
    else
        kubectl config use-context $1
    fi
}

function kupdate {
    pushd /tmp >/dev/null
    mkdir tanzu && cd "$_"
    wget -q --no-check-certificate https://sv-k8s.bonarea.net/wcp/plugin/linux-amd64/vsphere-plugin.zip
    unzip vsphere-plugin.zip >/dev/null
    chmod +x ./bin/kubectl
    sudo mv ./bin/* /usr/local/bin/
    cd ..
    rm -rf tanzu
    popd  >/dev/null
    kubectl version --client=true
}



#Personal
alias publish='~/publish/publish.sh'
alias deploy='~/publish/deploy.sh'
alias backup='~/backup.sh'
# detect system and sanitize env
case $(uname -s) in
	(Linux)
		_SYSNAME="linux"
		_FQDN=$(hostname --fqdn)
		_NODENAME=${_FQDN%%.*}
		_DOMAINNAME=${_FQDN#*.}
		;;
	(*)
		echo "error: unable to get system name"
		;;
esac

# get distribution specific data
_DISTNAME="unknown"

if [[ -f /etc/debian_version ]]; then
	_DISTNAME="debian"
fi

#!/bin/bash
# -*- coding: utf-8 -*-
#
#  build.sh
#
#  Copyright © 2014-2016 Antergos
#
#  This file is part of The Antergos Build Server, (AntBS).
#
#  AntBS is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  AntBS is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  The following additional terms are in effect as per Section 7 of the license:
#
#  The preservation of all legal notices and author attributions in
#  the material or in the Appropriate Legal Notices displayed
#  by works containing it is required.
#
#  You should have received a copy of the GNU General Public License
#  along with AntBS; If not, see <http://www.gnu.org/licenses/>.

DEPS=''
PKGS2_ADD_RM=( "$@" )
_filenames=()
_pkgnames=()
_generates=()



###
##
#    UTILITY FUNCTIONS
##
###


_2log() {
	echo '[\^/\^/^\^/^\^/\^/\^/^\^/^\^/] ' "$1" ' [\^/\^/^\^/^\^/\^/\^/^\^/^\^/]'
}


prepare_makepkg_and_pacman_configs() {
	local _32bit
	_32bit=$1

	[[ -z "${_32bit}" ]] && {
		cp /usr/share/devtools/makepkg-x86_64.conf /etc/makepkg.conf
		sed -i 's|unknown|x86_64|g' /etc/makepkg.conf
	}

	if [[ "${_ALEXPKG}" = "False" ]]; then
		echo "GPGKEY=24B445614FAC071891EDCE49CDBD406AA1AA7A1D" >> /etc/makepkg.conf
		export PACKAGER="Antergos Build Server <dev@antergos.com>"
		sed -i 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="Antergos Build Server <dev@antergos.com>"|g' /etc/makepkg.conf
		sed -i '/\[antergos-staging/,+1 d' /etc/pacman.conf
		sed -i '/\[antergos/,+1 d' /etc/pacman.conf
		sed -i '1s%^%[antergos]\nSigLevel = PackageRequired\nServer = file:///main/$arch\n%' /etc/pacman.conf
		sed -i '1s%^%[antergos-staging]\nSigLevel = PackageRequired\nServer = file:///staging/$arch\n%' /etc/pacman.conf

	else
		export PACKAGER="Alexandre Filgueira <alexfilgueira@cinnarch.com>"
		sed -i 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="Alexandre Filgueira <alexfilgueira@cinnarch.com>"|g' /etc/makepkg.conf
		sed -i '/\[antergos/,+1 d' /etc/pacman.conf
		sed -i '/\[antergos-staging/,+1 d' /etc/pacman.conf
		sed -i '1s%^%[antergos-staging]\nSigLevel = Never\nServer = file:///staging/$arch\n%' /etc/pacman.conf
	fi

	sed -i 's|CheckSpace||g' /etc/pacman.conf
	echo 'PKGDEST=/result' >> /etc/makepkg.conf

}

setup_environment() {
	export update_error='ERROR UPDATING STAGING REPO (BUILD FAILED)'
	export update_success='STAGING REPO UPDATE COMPLETE'
	export HOME=/pkg

	if [[ -f /pkg/PKGBUILD ]]; then
		source /pkg/PKGBUILD && export PKGNAME="${pkgname}"

		if [[ "${_is_metapkg}" = 'yes' ]]; then
			DEPS='-d'
			_2log 'METAPKG DETECTED'
		else
			DEPS='-s'
		fi

		chmod -R a+rw /pkg
		cd /pkg

	else
		_2log 'ERROR WHILE SETTING UP ENVIRONMENT (BUILD FAILED)'
		exit 1;
	fi

	prepare_makepkg_and_pacman_configs

	echo 'www-data:x:33:33:www-data:/var/www:/usr/sbin/nologin' >> /etc/passwd
	echo 'www-data:x:33:git,www-data' >> /etc/group

	git config --global user.name "Antergos Build Server"
	git config --global user.email "admin@antergos.org"
	echo -e '[user]\n\temail = "admin@antergos.org"\n\tname = "Antergos Build Server"\n' > /.gitconfig
	cp /.gitconfig /pkg

}


in_array() {
	local e

	for e in "${@:2}"; do
		[[ "$e" = "$1" ]] && return 0;
	done

	return 1
}


create_pkg_filenames_array() {
	local pkg2_add_rm

	for pkg2_add_rm in "${PKGS2_ADD_RM[@]}"; do
		if ! in_array "${pkg2_add_rm}" "${_filenames[@]}"; then
			_filenames+=("${pkg2_add_rm}.pkg.tar.xz")
		fi
	done && export _filenames
}


create_pkgnames_array() {
	local pkg2_add_rm
	local _name

	for pkg2_add_rm in "${PKGS2_ADD_RM[@]}"; do
		if ! in_array "${pkg2_add_rm}" "${_pkgnames[@]}"; then
			_name=$(echo "${pkg2_add_rm}" | cut -d '-' -f 0)
			_pkgnames+=( "${_name}" )
		fi
	done && export _pkgnames
}


create_pkgbuild_generates_array() {
	_2log 'Getting packages that would be generated by PKGBUILD...'

	{ [[ -n "$1" ]] && cd "$1" || cd /pkg; } && _generates+=( "$(sudo -u antbs makepkg --packagelist)" )

	_2log "${_generates[*]}"
}


#update_repo() {
#	_2log "UPDATING ${1} REPO";
#	create_pkg_filenames_array
#
#	for arc in x86_64 i686; do
#		cd "/${repo_dir}/${arc}"
#
#		for pkg2_add_rm in "${_filenames[@]}"; do
#			repo-add -R "${repo}.db.tar.gz" "${pkg2_add_rm}" && touch "/result/${pkg2_add_rm}"
#		done
#
#	done && return 0;
#
#	return 1
#}


#remove_pkg() {
#	local repo_dir=staging
#	local repo=antergos-staging
#
#	create_pkgnames_array
#	_2log "REMOVING ${_pkgnames[*]} FROM STAGING REPO"
#
#	for arc in i686 x86_64; do
#		cd "/${repo_dir}/${arc}"
#
#		for pkg2_rm in "${_pkgnames[@]}"; do
#			repo-remove "${repo}.db.tar.gz" "${pkg2_rm}"
#		done
#
#	done && return 0
#
#	return 1
#}

#symlink_any() {
#	local _file
#
#	cd "/${repo_dir}/x86_64"
#	create_pkg_filenames_array
#
#	for _file in "${_filenames[@]}"; do
#		[[ "${_file}" != **'-any.'** ]] && continue
#
#		if [[ -f ./"${_file}" ]]; then
#			_2log 'Creating symlinks for "any" package'
#			ln -sfr ./"${_file}" ../i686/"${_file}"
#		fi
#
#	done && return 0;
#
#	return 1;
#}


check_pkg_sums() {
	if [[ "${_AUTOSUMS}" = 'False' ]]; then
		if [[ ${1} = '' ]]; then
			sudo -u antbs /usr/bin/updpkgsums 2>&1 && return 0
		else
			arch-chroot /32build/root /usr/bin/bash -c 'cd /pkg; chmod -R a+rw /pkg; sudo -u antbs /usr/bin/updpkgsums' 2>&1 && return 0;
		fi
	else
		return 0
	fi

	return 1
}


setup_32bit_env() {
	chmod -R 777 /32build
	cp /usr/share/devtools/makepkg-i686.conf /32bit/makepkg.conf
	cp /etc/pacman.conf /32bit
	sed -i '/\[multilib/,+1 d;
		s|Architecture = auto|Architecture = i686|g; /32bit/pacman.conf
		s|file:\/\/\/main\/\$arch|http://repo.antergos.info/\$repo/\$arch|g;
		s|file:\/\/\/staging\/\$arch|http://repo.antergos.info/\$repo/\$arch|g;' /32bit/pacman.conf
	mkdir /run/shm || true

	if [[ "${_ALEXPKG}" = 'False' ]]; then
		echo "GPGKEY=24B445614FAC071891EDCE49CDBD406AA1AA7A1D" >> /32bit/makepkg.conf
		sed -i 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="Antergos Build Server <dev@antergos.com>"|g' /32bit/makepkg.conf
		cd /32bit

	else
		sed -i '/\[antergos/,+1 d' /32bit/pacman.conf
		sed -i 's|#PACKAGER="John Doe <john@doe.com>"|PACKAGER="Alexandre Filgueira <alexfilgueira@cinnarch.com>"|g' /32bit/makepkg.conf
		sed -i '/\[antergos-staging/,+1 d' /32bit/pacman.conf
		sed -i '1s%^%[antergos-staging]\nSigLevel = Never\nServer = file:///staging/$arch\n%' /32bit/pacman.conf
	fi

	sed -i 's|unknown|i686|g' /32bit/makepkg.conf

	if [[ -e /32build/root ]]; then
		rm -rf /32build/root
	fi

	mkarchroot -C /32bit/pacman.conf -M /32bit/makepkg.conf -c /var/cache/pacman_i686 /32build/root base-devel wget sudo git reflector
	mkdir /32build/root/pkg
	cp --copy-contents -t /32build/root/pkg /32bit/***
	cp /etc/pacman.d/antergos-mirrorlist /32build/root/etc/pacman.d

	for conf in /32bit/pacman.conf /32bit/makepkg.conf /etc/sudoers /etc/passwd /etc/group; do
		cp "${conf}" /32build/root/etc/
	done

	cp /etc/sudoers.d/10-builder /32build/root/etc/sudoers.d/
	sed -i '1s/^/CARCH="i686"\n/' /32build/root/pkg/PKGBUILD
	chmod a+rw /32build/root
	chmod a+rw /32build/root/pkg
	chmod 644 /32build/root/etc/sudoers
	chmod -R 644 /32build/root/etc/sudoers.d
	chmod 755 /32build/root/etc/sudoers.d
	chmod 700 /32build/root/usr/lib/sudo
	chmod 600 /32build/root/usr/lib/sudo/*.so
	# mount -o bind /var/cache/pacman_i686 /32build/root/var/cache/pacman
	arch-chroot /32build/root pacman -Syy --noconfirm --noprogressbar --color never
	arch-chroot /32build/root reflector -l 10 -f 5 --save /etc/pacman.d/mirrorlist
}


build_32bit_pkg() {
	_2log 'CREATING 32-BIT BUILD ENVIRONMENT' && setup_32bit_env
	_2log 'UPDATING 32BIT SOURCE CHECKSUMS' && check_pkg_sums 32bit
	cd /32bit

	{ arch-chroot \
			'/32build/root' \
			'/usr/bin/bash' \
			-c "cd /pkg; export IS_32BIT=i686; sudo -u antbs /usr/bin/makepkg -m -f -L ${DEPS} --noconfirm --needed" 2>&1 \
		&& cp /32build/root/pkg/*-i686.pkg.* /result \
		&& return 0; } || return 1
}


_output_pkgbuild_generates() {
	create_pkgbuild_generates_array
	echo "${_generates[*]}" >> /result/generates
}


try_build() {
	_2log 'TRYING BUILD';
	chmod -R a+rw /pkg
	chmod 777 /pkg

	if [[ "$1" = "i686" ]]; then

		{ build_32bit_pkg 2>&1 && return 0; } \
	||
		{ cd /result && rm **.pkg.**; return 1; }

	else
		cd /pkg && _2log 'UPDATING SOURCE CHECKSUMS';

		check_pkg_sums &&
		{ sudo -u antbs makepkg -m -f -L ${DEPS} --noconfirm --needed 2>&1 \
			&& _output_pkgbuild_generates \
			&& return 0; } || { cd /result && rm **.pkg.**; return 1; }
	fi
}


pkgbuild_produces_i686_package() {
	return $(in_array 'i686' "${arch[@]}" && ! in_array 'any' "${arch[@]}")
}


export_update_repo_env_vars() {
	export repo="${_REPO}"
	export repo_dir="${_REPO_DIR}"
	export RESULT="${_RESULT}"
}


build_package() {
	_2log 'SYNCING REPO DATABASES'
	reflector -l 10 -f 5 --save /etc/pacman.d/mirrorlist
	pacman -Syyu --noconfirm
	chmod -R a+rw /result && chmod 777 /tmp /var /var/tmp

	export repo=antergos-staging
	export repo_dir=staging

	if [[ -d /pkg/cnchi ]]; then
		rm -rf /pkg/cnchi
	fi

	if pkgbuild_produces_i686_package; then
		_2log 'i686 DETECTED'; cp --copy-contents -t /32bit /pkg/***

		{ try_build 2>&1 && try_build 'i686' 2>&1 && exit 0; } || exit 1
	else
		{ try_build 2>&1 && exit 0; } || exit 1
	fi

	# If we haven't exited before now then something went wrong. Build failed.
	#exit 1;
}


#exit_with_failed_status() {
#	_2log "${update_error}" && exit 1;
#}
#
#
#maybe_run_update_repo() {
#	if [[ "${_UPDREPO}" != "True" ]]; then
#		_2log 'Cannot update repo during build!'
#		return 1
#	fi
#
#	if [[ "${repo_dir}" = 'main' && "${RESULT}" = 'passed' ]]; then
#
#		{ update_repo "${repo}" && remove_pkg && _2log "${update_success}"; } || exit_with_failed_status
#
#	elif [[ "${repo_dir}" = 'main' && "${RESULT}" = 'failed' ]]; then
#
#		{ remove_pkg && _2log "${update_success}"; } || exit_with_failed_status
#
#	elif [[ "${repo_dir}" != 'main' ]]; then
#
#		{ update_repo "${repo}" && _2log "${update_success}"; } || exit_with_failed_status
#
#	else
#		_2log 'BUILD FAILED' && exit 1
#	fi
#}


###
##
#    DO STUFF
##
###


_2log 'SETTING UP ENVIRONMENT'
setup_environment

if [[ -n "${_GET_GENERATES}" ]]; then
	echo "${_generates[@]}" >> /result/generates
	exit 0
fi

build_package || { _2log 'BUILD FAILED' && exit 1; }

#while [[ -z "${ANTBS_STOP}" ]]
#do
#	sleep 15
#done


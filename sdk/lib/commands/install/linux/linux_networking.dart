// Copyright (C) 2026 Fiber
//
// All rights reserved. This script, including its code and logic, is the
// exclusive property of Fiber. Redistribution, reproduction,
// or modification of any part of this script is strictly prohibited
// without prior written permission from Fiber.
//
// Conditions of use:
// - The code may not be copied, duplicated, or used, in whole or in part,
//   for any purpose without explicit authorization.
// - Redistribution of this code, with or without modification, is not
//   permitted unless expressly agreed upon by Fiber.
// - The name "Fiber" and any associated branding, logos, or
//   trademarks may not be used to endorse or promote derived products
//   or services without prior written approval.
//
// Disclaimer:
// THIS SCRIPT AND ITS CODE ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL
// FIBER BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING BUT NOT LIMITED TO LOSS OF USE,
// DATA, PROFITS, OR BUSINESS INTERRUPTION) ARISING OUT OF OR RELATED TO THE USE
// OR INABILITY TO USE THIS SCRIPT, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Unauthorized copying or reproduction of this script, in whole or in part,
// is a violation of applicable intellectual property laws and will result
// in legal action.

import 'dart:io';

import '../../../core/commands/base/grep.dart';
import '../../../core/commands/base/mkdir.dart';
import '../../../core/commands/base/sh.dart';
import '../../../core/commands/linux/apt_get.dart';
import '../../../core/commands/linux/iptables.dart';
import '../../../core/commands/linux/iptables_save.dart';
import '../../../core/commands/linux/sysctl.dart';
import '../../../core/commands/linux/ufw.dart';
import '../../../core/process.dart';
import '../../../ops/project_command.dart';

mixin LinuxNetworking on ProjectCommand {
  Future<void> _persistSysctl(String setting) async {
    await streamPrivilegedCommand(
      Sysctl()
        ..write()
        ..setting(setting),
    );

    final Grep checkSetting = Grep()
      ..quiet()
      ..lineRegexp()
      ..fixedStrings()
      ..pattern(setting)
      ..file('/etc/sysctl.conf');
    await streamPrivilegedCommand(
      Sh()
        ..c()
        ..script("${commandLine(checkSetting)} || echo '$setting' >> /etc/sysctl.conf"),
    );
  }

  Iptables _wireguardNatRule({required bool insert}) {
    final Iptables iptables = Iptables()..table('nat');
    if (insert) {
      iptables.insert('POSTROUTING');
    } else {
      iptables.check('POSTROUTING');
    }
    return iptables
      ..source('10.8.0.0/24')
      ..destination('172.18.0.0/16')
      ..jump('RETURN');
  }

  Future<void> openLinuxFirewallAndVpnNetworking() async {
    log.info('Opening ports 80, 443, 51820/udp...');
    for (final String rule in ['80', '443', '51820/udp']) {
      await capturePrivilegedCommand(
        Ufw()
          ..allow()
          ..rule(rule),
      );
    }

    log.info('Installing iptables-persistent...');
    await streamPrivilegedCommand(
      AptGet()
        ..install()
        ..yes()
        ..package('netfilter-persistent')
        ..package('iptables-persistent'),
      env: {...Platform.environment, 'DEBIAN_FRONTEND': 'noninteractive'},
    );

    log.info('Configuring iptables preserving WireGuard source IPs through Docker NAT...');
    final ProcessResult natCheck = await capturePrivilegedCommand(_wireguardNatRule(insert: false));
    if (natCheck.exitCode != 0) {
      await streamPrivilegedCommand(_wireguardNatRule(insert: true));
    }

    final Mkdir makeIptablesDir = Mkdir()
      ..parents()
      ..path('/etc/iptables');
    await streamPrivilegedCommand(
      Sh()
        ..c()
        ..script('${commandLine(makeIptablesDir)} && ${commandLine(IptablesSave())} > /etc/iptables/rules.v4'),
    );

    log.info('Enabling kernel settings required by WireGuard (host network mode)...');
    await _persistSysctl('net.ipv4.ip_forward=1');
    await _persistSysctl('net.ipv4.conf.all.src_valid_mark=1');
  }
}

#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Ciriu Networks

cpupower() {
    governors=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors`
    while :; do
        clear
        show_menu_header "设置CPU电源模式"
        echo "  1. 设置CPU模式 conservative  保守模式   [变身老年机]"
        echo "  2. 设置CPU模式 ondemand       按需模式  [默认]"
        echo "  3. 设置CPU模式 powersave      节能模式  [省电小能手]"
        echo "  4. 设置CPU模式 performance   性能模式   [性能释放]"
        echo "  5. 设置CPU模式 schedutil      负载模式  [交给负载自动配置]"
        echo
        echo "  6. 恢复系统默认电源设置"
        echo "${UI_DIVIDER}"
        show_menu_option "0" "返回"
        show_menu_footer
        echo
        echo "部分CPU仅支持 performance 和 powersave 模式，只能选择这两项，其他模式无效不要选！"
        echo
        echo "你的CPU支持 ${governors} 模式"
        echo
        read -p "请选择: [ ]" -n 1 cpupowerid
        echo  # New line after input
        cpupowerid=${cpupowerid:-2}
        case "${cpupowerid}" in
            1)
                GOVERNOR="conservative"
                ;;
            2)
                GOVERNOR="ondemand"
                ;;
            3)
                GOVERNOR="powersave"
                ;;
            4)
                GOVERNOR="performance"
                ;;
            5)
                GOVERNOR="schedutil"
                ;;
            6)
                cpupower_del
                pause_function
                break
                ;;
            0)
                break
                ;;
            *)
                log_error "你的输入无效，请重新输入！"
                pause_function
                ;;
        esac
        if [[ ${GOVERNOR} != "" ]]; then
            if [[ -n `echo "${governors}" | grep -o "${GOVERNOR}"` ]]; then
                echo "您选择的CPU模式：${GOVERNOR}"
                echo
                cpupower_add
                pause_function
            else
                log_error "您的CPU不支持该模式！"
                log_tips "现在暂时不会对你的系统造成影响，但是下次开机时，CPU模式会恢复为默认模式。"
                pause_function
            fi
        fi
    done
}

# 修改CPU模式
cpupower_add() {
    echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    echo "查看当前CPU模式"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

    echo "正在添加开机任务"
    NEW_CRONTAB_COMMAND="sleep 10 && echo "${GOVERNOR}" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null #CPU Power Mode"
    EXISTING_CRONTAB=$(crontab -l 2>/dev/null)
    if [[ -n "$EXISTING_CRONTAB" ]]; then
        TEMP_CRONTAB_FILE=$(mktemp)
        # 使用 -F 精确匹配标记，避免误删用户的其他任务
        echo "$EXISTING_CRONTAB" | grep -vF "#CPU Power Mode" > "$TEMP_CRONTAB_FILE"
        crontab "$TEMP_CRONTAB_FILE"
        rm "$TEMP_CRONTAB_FILE"
    fi
    log_success "CPU模式已修改完成"
    # 修改完成
    (crontab -l 2>/dev/null; echo "@reboot $NEW_CRONTAB_COMMAND") | crontab -
    echo -e "
检查计划任务设置 (使用 'crontab -l' 命令来检查)"
}

# 恢复系统默认电源设置
cpupower_del() {
    # 恢复性模式
    echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    # 删除计划任务
    EXISTING_CRONTAB=$(crontab -l 2>/dev/null)
    if [[ -n "$EXISTING_CRONTAB" ]]; then
        TEMP_CRONTAB_FILE=$(mktemp)
        # 使用 -F 精确匹配标记，避免误删用户的其他任务
        echo "$EXISTING_CRONTAB" | grep -vF "#CPU Power Mode" > "$TEMP_CRONTAB_FILE"
        crontab "$TEMP_CRONTAB_FILE"
        rm "$TEMP_CRONTAB_FILE"
    fi

    log_success "已恢复系统默认电源设置！还是默认的好用吧"
}
#--------------设置CPU电源模式----------------

#--------------CPU、主板、硬盘温度显示----------------
# 安装工具
cpu_add() {
    nodes="/usr/share/perl5/PVE/API2/Nodes.pm"
    pvemanagerlib="/usr/share/pve-manager/js/pvemanagerlib.js"
    proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

    pvever=$(pveversion | awk -F"/" '{print $2}')
    echo pve版本$pvever

    # 判断是否已经执行过修改 (使用 modbyshowtempfreq 标记检测)
    if [ $(grep 'modbyshowtempfreq' $nodes $pvemanagerlib $proxmoxlib 2>/dev/null | wc -l) -eq 3 ]; then
        log_warn "已经修改过，请勿重复修改"
        log_tips "如果没有生效，请使用 Shift+F5 刷新浏览器缓存"
        log_tips "如果需要强制重新修改，请先执行还原操作"
        pause_function
        return
    fi

    # 先刷新下源
    log_step "更新软件包列表..."
    apt-get update

    log_step "开始安装所需工具..."
    # 安装温度监控基础软件包；UPS 依赖按需安装
    packages=(lm-sensors nvme-cli sysstat linux-cpupower hdparm smartmontools)

    # 查询软件包，判断是否安装
    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            log_info "$package 未安装，开始安装软件包"
            apt-get install "${packages[@]}" -y
            modprobe msr
            install=ok
            break
        fi
    done

    # 设置执行权限 (修正路径)
    [[ -e /usr/sbin/linux-cpupower ]] && chmod +s /usr/sbin/linux-cpupower
    chmod +s /usr/sbin/nvme
    chmod +s /usr/sbin/smartctl
    chmod +s /usr/sbin/turbostat || log_warn "无法设置 turbostat 权限"

    # 启用 MSR 模块
    modprobe msr && echo msr > /etc/modules-load.d/turbostat-msr.conf

    # 软件包安装完成
    if [ "$install" == "ok" ]; then
        log_success "软件包安装完成，检测硬件信息"
        sensors-detect --auto > /tmp/sensors
        drivers=$(sed -n '/Chip drivers/,/\#----cut here/p' /tmp/sensors | sed '/Chip /d' | sed '/cut/d')

        if [ $(echo $drivers | wc -w) = 0 ]; then
            log_warn "没有找到任何驱动，似乎你的系统不支持或驱动安装失败。"
            pause_function
        else
            for i in $drivers; do
                modprobe $i
                if [ $(grep $i /etc/modules | wc -l) = 0 ]; then
                    echo $i >> /etc/modules
                fi
            done
            sensors
            sleep 3
            log_success "驱动信息配置成功。"
        fi
        [[ -e /etc/init.d/kmod ]] && /etc/init.d/kmod start
        rm /tmp/sensors
    fi

    log_step "备份源文件"
    # 备份当前版本文件
    backup_file "$nodes"
    backup_file "$pvemanagerlib"
    backup_file "$proxmoxlib"

    local enable_ups=false
    local nut_ups_name=""
    local nut_ups_target=""

    log_info "是否启用 UPS 监控？"
    echo -n "（使用 NUT / upsc 采集，如果没有 UPS 设备或不想显示，请选择 N，默认N）(y/N): "
    read -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_ups=true
        read -r -p "请输入 NUT UPS 设备名 [默认: ups]: " nut_ups_name
        nut_ups_name=${nut_ups_name:-ups}
        if [[ ! "$nut_ups_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
            log_warn "UPS 设备名包含不支持字符，已回退为默认值 ups"
            nut_ups_name="ups"
        fi
        nut_ups_target="${nut_ups_name}@localhost"
        log_success "已选择启用 UPS 监控 (NUT: ${nut_ups_target})"

        if ! dpkg -s nut-client &> /dev/null; then
            log_info "nut-client 未安装，开始安装以提供 upsc 命令"
            apt-get install nut-client -y
        fi

        if command -v upsc >/dev/null 2>&1; then
            log_info "已检测到 upsc，UPS 数据将通过带超时保护的读取方式展示"
        else
            log_warn "未检测到 upsc，UPS 信息将显示为不可用"
        fi

        log_info "脚本不会自动启停 NUT 服务，请保持现有 NUT 配置不变"
    else
        enable_ups=false
        log_info "已选择跳过 UPS 监控"
        log_info "已跳过 UPS 展示，脚本不会改动系统当前的 NUT 服务状态"
    fi

    # 生成系统变量 (参考 PVE 8 脚本的改进实现)
    tmpf=tmpfile.temp
    touch $tmpf
    cat > $tmpf << 'EOF'

#modbyshowtempfreq

        $res->{thermalstate} = `sensors -A`;
        $res->{cpuFreq} = `
            goverf=/sys/devices/system/cpu/cpufreq/policy0/scaling_governor
            maxf=/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq
            minf=/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_min_freq

            cat /proc/cpuinfo | grep -i "cpu mhz"
            echo -n 'gov:'
            [ -f \$goverf ] && cat \$goverf || echo none
            echo -n 'min:'
            [ -f \$minf ] && cat \$minf || echo none
            echo -n 'max:'
            [ -f \$maxf ] && cat \$maxf || echo none
            echo -n 'pkgwatt:'
            [ -e /usr/sbin/turbostat ] && turbostat --quiet --cpu package --show "PkgWatt" -S sleep 0.25 2>&1 | tail -n1
        `;
EOF

    if [ "$enable_ups" = true ]; then
        cat >> $tmpf << EOF
        \$res->{ups_status} = qx'
            UPS_TARGET="$nut_ups_target"
            if command -v upsc >/dev/null 2>&1; then
                if command -v timeout >/dev/null 2>&1; then
                    UPS_DATA=\$(timeout --signal=TERM 3s upsc "\$UPS_TARGET" 2>/dev/null)
                    UPS_EXIT=\$?
                    if [ "\$UPS_EXIT" -eq 0 ] && [ -n "\$UPS_DATA" ]; then
                        FILTERED_DATA=\$(printf "%s\n" "\$UPS_DATA" | grep -E "^(device\.model|ups\.status|battery\.charge|battery\.runtime|input\.voltage|output\.voltage|ups\.load|ups\.power\.nominal|ups\.realpower\.nominal|ups\.realpower|battery\.charge\.low|battery\.voltage|ups\.beeper\.status|ups\.delay\.shutdown|ups\.timer\.shutdown|ups\.delay\.start|ups\.timer\.start):" || true)
                        if [ -n "\$FILTERED_DATA" ]; then
                            printf "%s\n" "\$FILTERED_DATA"
                            echo "UPS_TARGET: \$UPS_TARGET"
                        else
                            echo "NUT_STATUS: NO_DATA"
                            echo "UPS_TARGET: \$UPS_TARGET"
                        fi
                    elif [ "\$UPS_EXIT" -eq 124 ] || [ "\$UPS_EXIT" -eq 137 ]; then
                        echo "NUT_STATUS: TIMEOUT"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    elif [ "\$UPS_EXIT" -eq 0 ]; then
                        echo "NUT_STATUS: NO_DATA"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    else
                        echo "NUT_STATUS: QUERY_FAILED"
                        echo "UPS_TARGET: \$UPS_TARGET"
                    fi
                else
                    echo "NUT_STATUS: TIMEOUT_MISSING"
                    echo "UPS_TARGET: \$UPS_TARGET"
                fi
            else
                echo "NUT_STATUS: UPSC_MISSING"
                echo "UPS_TARGET: \$UPS_TARGET"
            fi
        ';
EOF
    fi


    echo >> $tmpf

    # NVME 硬盘变量 (动态检测，参考 PVE 8 实现)
    log_info "检测系统中的 NVME 硬盘"
    nvi=0
    for nvme in $(ls /dev/nvme[0-9] 2> /dev/null); do
        chmod +s /usr/sbin/smartctl 2>/dev/null

        cat >> $tmpf << EOF

        \$res->{nvme$nvi} = \`smartctl $nvme -a -j\`;
EOF
        echo "检测到 NVME 硬盘: $nvme (nvme$nvi)"
        let nvi++
    done
    echo "已添加 $nvi 块 NVME 硬盘"

    # SATA 硬盘变量 (动态检测，参考 PVE 8 实现)
    log_info "检测系统中的 SATA 固态和机械硬盘"
    sdi=0
    for sd in $(ls /dev/sd[a-z] 2> /dev/null); do
        chmod +s /usr/sbin/smartctl 2>/dev/null
        chmod +s /usr/sbin/hdparm 2>/dev/null

        # 检测是否是真的硬盘
        sdsn=$(awk -F '/' '{print $NF}' <<< $sd)
        sdcr=/sys/block/$sdsn/queue/rotational
        [ -f $sdcr ] || continue

        if [ "$(cat $sdcr)" = "0" ]; then
            hddisk=false
            sdtype="固态硬盘"
        else
            hddisk=true
            sdtype="机械硬盘"
        fi

        # 硬盘输出信息逻辑，如果硬盘不存在就输出空 JSON
        cat >> $tmpf << EOF

        \$res->{sd$sdi} = \`
            if [ -b $sd ]; then
                # 增加 SAS 盘检测，SAS 盘不使用 hdparm 检测休眠，防止误报
                if $hddisk && ! smartctl -i $sd | grep -q "Transport protocol:.*SAS" && hdparm -C $sd 2>/dev/null | grep -iq 'standby'; then
                    echo '{"standy": true}'
                else
                    smartctl $sd -a -j
                fi
            else
                echo '{}'
            fi
        \`;
EOF
        echo "检测到 $sdtype: $sd (sd$sdi)"
        let sdi++
    done
    echo "已添加 $sdi 块 SATA 固态和机械硬盘"


    ###################  修改node.pm   ##########################
    log_info "修改node.pm："
    log_info "找到关键字 PVE::pvecfg::version_text 的行号并跳到下一行"

    # 显示匹配的行
    ln=$(expr $(sed -n -e '/PVE::pvecfg::version_text/=' $nodes) + 1)
    echo "匹配的行号：" $ln

    log_info "修改结果："
    sed -i "${ln}r $tmpf" $nodes
    # 显示修改结果
    sed -n '/PVE::pvecfg::version_text/,+18p' $nodes
    rm $tmpf

    ###################  修改pvemanagerlib.js   ##########################
    tmpf=tmpfile.temp
    touch $tmpf
    cat > $tmpf << 'EOF'

//modbyshowtempfreq
    {
          itemId: 'cpumhz',
          colspan: 2,
          printBar: false,
          title: gettext('CPU频率(GHz)'),
          textField: 'cpuFreq',
          renderer:function(v){
              console.log(v);

              // 解析所有核心频率
              let m = v.match(/(?<=^cpu[^\d]+)\d+/img);
              if (!m || m.length === 0) {
                  return '无法获取CPU频率信息';
              }

              let freqs = m.map(e => parseFloat((e / 1000).toFixed(1)));

              // 计算统计信息
              let avgFreq = (freqs.reduce((a, b) => a + b, 0) / freqs.length).toFixed(1);
              let minFreq = Math.min(...freqs).toFixed(1);
              let maxFreq = Math.max(...freqs).toFixed(1);
              let coreCount = freqs.length;

              // 获取系统配置的频率范围
              let sysMin = (v.match(/(?<=^min:).+/im)[0]);
              if (sysMin !== 'none') {
                  sysMin = (sysMin / 1000000).toFixed(1);
              }

              let sysMax = (v.match(/(?<=^max:).+/im)[0]);
              if (sysMax !== 'none') {
                  sysMax = (sysMax / 1000000).toFixed(1);
              }

              let gov = v.match(/(?<=^gov:).+/im)[0].toUpperCase();

              let watt = v.match(/(?<=^pkgwatt:)[\d.]+$/im);
              watt = watt ? " | 功耗: " + (watt[0]/1).toFixed(1) + 'W' : '';

              // 简洁显示：平均值 + 当前范围 + 系统范围 + 功耗 + 调速器
              return `${coreCount}核心 平均: ${avgFreq} GHz (当前: ${minFreq}~${maxFreq}) | 范围: ${sysMin}~${sysMax} GHz${watt} | 调速器: ${gov}`;
           }
    },

    {
          itemId: 'thermal',
          colspan: 2,
          printBar: false,
	          title: gettext('CPU温度'),
	          textField: 'thermalstate',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 60) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	                  }
	                  if (tempNum < 80) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum.toFixed(0) + '°C</span>';
	              }

	              console.log(value);
              let b = value.trim().split(/\s+(?=^\w+-)/m).sort();
              let cpuResults = [];
              let otherResults = [];

              const cpuSensorRegex = /(CORETEMP|K10TEMP|ZENPOWER|ZENPOWER3|K8TEMP|FAM15H|ZENPROBE)/i;
              const amdLabelRegex = /\bT(CTL|DIE|CCD|CCD\d+|Sx|LOOP)\b/i;

              b.forEach(function(v){
                  // 风扇转速数据
                  let fandata = v.match(/(?<=:\s+)[1-9]\d*(?=\s+RPM\s+)/ig);
                  if (fandata) {
                      otherResults.push('风扇: ' + fandata.join(', ') + ' RPM');
                      return;
                  }

                  let name = v.match(/^[^-]+/);
                  if (!name) return;
                  name = name[0].toUpperCase();

                  let temps = v.match(/(?<=:\s+)[+-][\d.]+(?=.?°C)/g);
                  if (!temps) return;

                  temps = temps.map(t => parseFloat(t));

                  // 只处理 CPU 温度（Intel coretemp 或 AMD 相关传感器）
                  const isCpuSensor = cpuSensorRegex.test(name) || amdLabelRegex.test(v);

	                  if (isCpuSensor) {
	                      let packageTemp = temps[0];

	                      if (temps.length > 1) {
	                          let coreTemps = temps.slice(1);
	                          let avgCore = coreTemps.reduce((a, b) => a + b, 0) / coreTemps.length;
	                          let maxCore = Math.max(...coreTemps);
	                          let minCore = Math.min(...coreTemps);

	                          cpuResults.push(`封装: ${colorizeTemp(packageTemp)} | 核心: 平均 ${colorizeTemp(avgCore)} (${colorizeTemp(minCore)}~${colorizeTemp(maxCore)})`);
	                      } else {
	                          cpuResults.push(`封装: ${colorizeTemp(packageTemp)}`);
	                      }

	                      // 添加临界温度
	                      let crit = v.match(/(?<=\bcrit\b[^+]+\+)\d+/);
	                      if (crit) {
	                          cpuResults[cpuResults.length - 1] += ` | 临界: ${colorizeTemp(crit[0])}`;
	                      }
	                  } else {
	                      // 非 CPU 温度（主板、NVME等）放到其他结果中
	                      let tempStr = `${name}: ${colorizeTemp(temps[0])}`;
	                      let crit = v.match(/(?<=\bcrit\b[^+]+\+)\d+/);
	                      if (crit) {
	                          tempStr += ` (临界: ${colorizeTemp(crit[0])})`;
	                      }
                      otherResults.push(tempStr);
                  }
              });

              // 只返回 CPU 相关温度，其他传感器信息不显示在这里
              // （NVME温度会在NVME硬盘信息中单独显示）
              if (cpuResults.length === 0) {
                  return '未获取到CPU温度信息';
              }

              // 如果有多个CPU（如双路服务器），分别显示
              if (cpuResults.length > 1) {
                  return cpuResults.map((temp, idx) => `CPU${idx}: ${temp}`).join(' | ');
              } else {
                  return cpuResults[0];
              }
           }
    },
EOF

    # 动态为每个 NVME 硬盘添加 JavaScript 代码
    for i in $(seq 0 $((nvi - 1))); do
        cat >> $tmpf << EOF

    {
          itemId: 'nvme${i}0',
          colspan: 2,
          printBar: false,
	          title: gettext('NVME${i}'),
	          textField: 'nvme${i}',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 50) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  if (tempNum < 70) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum + '°C</span>';
	              }

	              function colorizeHealth(percent) {
	                  let healthNum = Number(percent);
	                  if (Number.isNaN(healthNum)) {
	                      return percent + '%';
	                  }
	                  if (healthNum >= 80) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + healthNum + '%</span>';
	                  }
	                  if (healthNum >= 50) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + healthNum + '%</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + healthNum + '%</span>';
	              }

	              try{
	                  let  v = JSON.parse(value);

                  // 检查是否为空 JSON（硬盘不存在或已直通）
                  if (Object.keys(v).length === 0) {
                      return '<span style="color: #888;">未检测到 NVME（可能已直通或移除）</span>';
                  }

                  // 检查型号
                  let model = v.model_name;
                  if (!model) {
                      return '<span style="color: #f39c12;">NVME 信息不完整（建议检查连接状态）</span>';
                  }

                  // 构建显示内容
                  let parts = [model];
                  let hasData = false;

	                  // 温度
	                  if (v.temperature?.current !== undefined) {
	                      parts.push('温度: ' + colorizeTemp(v.temperature.current));
	                      hasData = true;
	                  }

                  // 健康度和读写
                  let log = v.nvme_smart_health_information_log;
	                  if (log) {
	                      // 健康度
	                      if (log.percentage_used !== undefined) {
	                          let healthRemain = 100 - log.percentage_used;
	                          let health = '健康: ' + colorizeHealth(healthRemain);
	                          if (log.media_errors !== undefined && log.media_errors > 0) {
	                              health += ' <span style="color: #e74c3c;">(0E: ' + log.media_errors + ')</span>';
	                          }
	                          parts.push(health);
	                          hasData = true;
	                      }

	                      if (log.unsafe_shutdowns !== undefined) {
	                          let shutdownColor = Number(log.unsafe_shutdowns) > 0 ? '#e74c3c' : '#27ae60';
	                          parts.push('异常断电: <span style="color: ' + shutdownColor + '; font-weight: 600;">' + log.unsafe_shutdowns + '</span>');
	                          hasData = true;
	                      }

	                      // 读写
                      if (log.data_units_read && log.data_units_written) {
                          let read = (log.data_units_read / 1956882).toFixed(1);
                          let write = (log.data_units_written / 1956882).toFixed(1);
                          parts.push('读写: ' + read + 'T / ' + write + 'T');
                          hasData = true;
                      }
                  }

                  // 通电时间
                  if (v.power_on_time?.hours !== undefined) {
                      let pot = '通电: ' + v.power_on_time.hours + '时';
                      if (v.power_cycle_count) {
                          pot += ' (次: ' + v.power_cycle_count + ')';
                      }
                      parts.push(pot);
                      hasData = true;
                  }

                  // SMART 状态
                  if (v.smart_status?.passed !== undefined) {
                      parts.push('SMART: ' + (v.smart_status.passed ? '<span style="color: #27ae60;">正常</span>' : '<span style="color: #e74c3c;">警告!</span>'));
                      hasData = true;
                  }

                  // 如果只有型号，没有其他数据，说明可能是权限或驱动问题
                  if (!hasData) {
                      return model + ' <span style="color: #888;">| 无法获取详细信息（检查 smartctl 权限或驱动）</span>';
                  }

                  return parts.join(' | ');

              }catch(e){
                  return '<span style="color: #888;">无法解析 NVME 信息（可能使用控制器直通）</span>';
              };

           }
    },
EOF
    done

    # 动态为每个 SATA 硬盘添加 JavaScript 代码
    for i in $(seq 0 $((sdi - 1))); do
        # 获取硬盘类型（固态/机械）
        sd="/dev/sd$(echo {a..z} | cut -d' ' -f$((i+1)))"
        sdsn=$(basename $sd 2>/dev/null)
        sdcr=/sys/block/$sdsn/queue/rotational
        if [ -f $sdcr ] && [ "$(cat $sdcr)" = "0" ]; then
            sdtype="固态硬盘$i"
        else
            sdtype="机械硬盘$i"
        fi

        cat >> $tmpf << EOF

    {
          itemId: 'sd${i}0',
          colspan: 2,
          printBar: false,
	          title: gettext('${sdtype}'),
	          textField: 'sd${i}',
	          renderer:function(value){
	              function colorizeTemp(temp) {
	                  let tempNum = Number(temp);
	                  if (Number.isNaN(tempNum)) {
	                      return temp + '°C';
	                  }
	                  if (tempNum < 40) {
	                      return '<span style="color: #27ae60; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  if (tempNum < 50) {
	                      return '<span style="color: #f39c12; font-weight: 600;">' + tempNum + '°C</span>';
	                  }
	                  return '<span style="color: #e74c3c; font-weight: 600;">' + tempNum + '°C</span>';
	              }

	              function findAtaSmartRawValue(table, ids) {
	                  if (!Array.isArray(table)) {
	                      return null;
	                  }
	                  let found = table.find(item => ids.includes(item?.id));
	                  if (!found || !found.raw) {
	                      return null;
	                  }
	                  return found.raw.string ?? found.raw.value ?? null;
	              }

	              try{
	                  let  v = JSON.parse(value);
	                  console.log(v)

                  // 场景 1：硬盘休眠（节能模式）
                  if (v.standy === true) {
                      return '<span style="color: #27ae60;">硬盘休眠中（省电模式）</span>'
                  }

                  // 场景 2：空 JSON（硬盘不存在或已直通）
                  if (Object.keys(v).length === 0) {
                      return '<span style="color: #888;">未检测到硬盘（可能已直通或移除）</span>';
                  }

                  // 场景 3：检查型号
                  let model = v.model_name;
                  if (!model) {
                      return '<span style="color: #f39c12;">硬盘信息不完整（建议检查连接状态）</span>';
                  }

                  // 场景 4：构建正常显示内容
                  let parts = [model];

	                  // 温度
	                  if (v.temperature?.current !== undefined) {
	                      parts.push('温度: ' + colorizeTemp(v.temperature.current));
	                  }

                  // 通电时间
                  if (v.power_on_time?.hours !== undefined) {
                      let pot = '通电: ' + v.power_on_time.hours + '时';
                      if (v.power_cycle_count) {
                          pot += ',次: ' + v.power_cycle_count;
                      }
                      parts.push(pot);
                  }

	                  // SMART 状态
	                  if (v.smart_status?.passed !== undefined) {
	                      parts.push('SMART: ' + (v.smart_status.passed ? '<span style="color: #27ae60;">正常</span>' : '<span style="color: #e74c3c;">警告!</span>'));
	                  }

	                  let unsafeShutdowns = findAtaSmartRawValue(v.ata_smart_attributes?.table, [174, 192]);
	                  if (unsafeShutdowns !== null && unsafeShutdowns !== undefined && unsafeShutdowns !== '') {
	                      let shutdownCount = String(unsafeShutdowns).trim();
	                      let shutdownColor = Number(shutdownCount) > 0 ? '#e74c3c' : '#27ae60';
	                      parts.push('异常断电: <span style="color: ' + shutdownColor + '; font-weight: 600;">' + shutdownCount + '</span>');
	                  }

                  return parts.join(' | ');

              }catch(e){
                  // JSON 解析失败
                  return '<span style="color: #888;">无法获取硬盘信息（可能使用 HBA 直通）</span>';
              };
           }
    },
EOF
    done

    if [ "$enable_ups" = true ]; then
        cat >> $tmpf << 'EOF'

    {
        itemId: 'ups-status',
        colspan: 2,
        printBar: false,
        title: gettext('UPS 信息'),
        textField: 'ups_status',
        cellWrap: true,
        renderer: function(value) {
            if (!value || value.length === 0) {
                return '提示: 未检测到 UPS 或 NUT 未返回数据';
            }

            try {
                const getValue = (key) => {
                    const match = value.match(new RegExp(`^${key}\\s*:\\s*(.+)$`, 'm'));
                    return match ? match[1].trim() : '';
                };

                const target = getValue('UPS_TARGET');
                const model = getValue('device\\.model') || '未知型号';
                const statusRaw = getValue('ups\\.status');
                const charge = getValue('battery\\.charge') || '-';
                const runtimeRaw = getValue('battery\\.runtime');
                const inputVoltage = getValue('input\\.voltage');
                const outputVoltage = getValue('output\\.voltage');
                const loadRaw = getValue('ups\\.load');
                const nominalPowerRaw = getValue('ups\\.realpower\\.nominal') || getValue('ups\\.power\\.nominal');
                const realPowerRaw = getValue('ups\\.realpower');
                const batteryVoltage = getValue('battery\\.voltage');
                const beeper = getValue('ups\\.beeper\\.status');
                const delayShutdown = getValue('ups\\.delay\\.shutdown');
                const timerShutdown = getValue('ups\\.timer\\.shutdown');
                const delayStart = getValue('ups\\.delay\\.start');
                const timerStart = getValue('ups\\.timer\\.start');
                const noData = getValue('NUT_STATUS');

                if (noData === 'UPSC_MISSING') {
                    return `提示: 系统未安装 upsc，无法读取 ${target || 'UPS'} 的信息`;
                }
                if (noData === 'TIMEOUT_MISSING') {
                    return `提示: 系统未检测到 timeout，为避免阻塞 Web UI，已跳过 ${target || 'UPS'} 的读取`;
                }
                if (noData === 'TIMEOUT') {
                    return `提示: 读取 ${target || 'UPS'} 超时，已自动跳过以保护 Web UI`;
                }
                if (noData === 'NO_DATA') {
                    return `提示: 未从 ${target || 'UPS'} 获取到 NUT 数据`;
                }
                if (noData === 'QUERY_FAILED') {
                    return `提示: ${target || 'UPS'} 查询失败，请检查 NUT 配置或设备名`;
                }

                const statusTokens = statusRaw ? statusRaw.split(/\s+/).filter(Boolean) : [];
                const statusTexts = [];
                if (statusTokens.includes('OL')) statusTexts.push('在线');
                if (statusTokens.includes('OB')) statusTexts.push('电池供电');
                if (statusTokens.includes('CHRG')) statusTexts.push('充电中');
                if (statusTokens.includes('DISCHRG')) statusTexts.push('放电中');
                if (statusTokens.includes('LB')) statusTexts.push('低电量');
                if (statusTexts.length === 0) statusTexts.push(statusRaw || '未知状态');

                const runtimeSeconds = Number.parseFloat(runtimeRaw);
                const runtimeText = Number.isFinite(runtimeSeconds)
                    ? `${Math.round(runtimeSeconds)} 秒`
                    : '-';

                const loadPct = Number.parseFloat(loadRaw);
                const nominalPower = Number.parseFloat(nominalPowerRaw);
                const realPower = Number.parseFloat(realPowerRaw);

                let powerText = '-';
                if (Number.isFinite(realPower) && realPower > 0) {
                    powerText = `${realPower.toFixed(0)} W`;
                } else if (Number.isFinite(nominalPower) && Number.isFinite(loadPct)) {
                    powerText = `${(nominalPower * loadPct / 100).toFixed(0)} W`;
                }

                const nominalPowerText = Number.isFinite(nominalPower) && nominalPower > 0
                    ? `${nominalPower.toFixed(0)} W`
                    : '-';

                const voltageParts = [];
                if (inputVoltage) voltageParts.push(`输入电压: ${inputVoltage} V`);
                if (outputVoltage) voltageParts.push(`输出电压: ${outputVoltage} V`);
                if (batteryVoltage) voltageParts.push(`电池电压: ${batteryVoltage} V`);

                const extraParts = [];
                if (beeper) extraParts.push(`蜂鸣器: ${beeper}`);
                if (delayShutdown) extraParts.push(`延迟关机: ${delayShutdown} 秒`);
                if (timerShutdown) extraParts.push(`关机计时: ${timerShutdown} 秒`);
                if (delayStart) extraParts.push(`延迟启动: ${delayStart} 秒`);
                if (timerStart) extraParts.push(`启动计时: ${timerStart} 秒`);

                return `${model}${target ? ` (${target})` : ''} | 状态: ${statusTexts.join(' / ')}<br>
                        电量: ${charge} % | 剩余时间: ${runtimeText} | 负载: ${loadRaw || '-'} %<br>
                        ${voltageParts.length > 0 ? voltageParts.join(' | ') : '电压: -'}<br>
                        额定功率: ${nominalPowerText} | 当前功率: ${powerText}${extraParts.length > 0 ? `<br>${extraParts.join(' | ')}` : ''}`;
            } catch(e) {
                return 'UPS 信息解析失败: ' + value;
            }
        }
    },
EOF
    fi

    log_info "找到关键字pveversion的行号"
    # 显示匹配的行
    ln=$(sed -n '/pveversion/,+10{/},/{=;q}}' $pvemanagerlib)
    echo "匹配的行号pveversion：" $ln

    log_info "修改结果："
    sed -i "${ln}r $tmpf" $pvemanagerlib
    # 显示修改结果
    # sed -n '/pveversion/,+30p' $pvemanagerlib

    log_info "修改页面高度"
    # 统计添加了几条内容（2个基础项 + NVME + SATA + UPS）
    if [ "$enable_ups" = true ]; then
        addRs=$((2 + nvi + sdi + 1))
        ups_info="+ 1 个UPS"
    else
        addRs=$((2 + nvi + sdi))
        ups_info=""
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "检测到添加了 $addRs 条监控项 (2个基础项 + $nvi 个NVME + $sdi 个SATA $ups_info)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "请选择高度调整方式："
    echo "  1. 自动计算 (推荐，参考 PVE 8 算法：28px/项)"
    echo "  2. 手动设置 (自定义每项的高度增量)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "请输入选项 [1-2] (直接回车使用自动计算): " height_choice

    case ${height_choice:-1} in
        1)
            # 自动计算：每项 28px
            addHei=$((28 * addRs))
            log_info "使用自动计算：$addRs 项 × 28px = ${addHei}px"
            ;;
        2)
            # 手动设置
            echo
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "手动设置说明："
            echo "  - 推荐值范围: 20-40 (默认 28)"
            echo "  - 如果 CPU 核心很多或想显示更多信息，可适当增大"
            echo "  - 如果界面出现遮挡，可适当减小此值"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            read -p "请输入每项的高度增量 (px) [默认: 28]: " height_per_item

            # 验证输入是否为数字，如果不是或为空则使用默认值 28
            if [[ -z "$height_per_item" ]] || ! [[ "$height_per_item" =~ ^[0-9]+$ ]]; then
                height_per_item=28
                log_info "使用默认值: 28px/项"
            else
                log_info "使用自定义值: ${height_per_item}px/项"
            fi

            addHei=$((height_per_item * addRs))
            log_success "计算结果：$addRs 项 × ${height_per_item}px = ${addHei}px"
            ;;
        *)
            # 无效选项，使用自动计算
            addHei=$((28 * addRs))
            log_warn "无效选项，使用自动计算：${addHei}px"
            ;;
    esac

    rm $tmpf

    # 修改左栏高度（原高度 300）
    log_step "修改左栏高度"
    wph=$(sed -n -E "/widget\.pveNodeStatus/,+4{/height:/{s/[^0-9]*([0-9]+).*/\1/p;q}}" $pvemanagerlib)
    if [ -n "$wph" ]; then
        sed -i -E "/widget\.pveNodeStatus/,+4{/height:/{s#[0-9]+#$((wph + addHei))#}}" $pvemanagerlib
        echo "左栏高度: $wph → $((wph + addHei))" >> /var/log/pve-tools.log
    else
        log_warn "找不到左栏高度修改点"
    fi

    log_info "跳过强制修改右栏 minHeight，避免磁盘较多时图表区域被异常拉高"

    # 调整显示布局
    ln=$(expr $(sed -n -e '/widget.pveDcGuests/=' $pvemanagerlib) + 10)
    sed -i "${ln}a\ textAlign: 'right'," $pvemanagerlib
    ln=$(expr $(sed -n -e '/widget.pveNodeStatus/=' $pvemanagerlib) + 10)
    sed -i "${ln}a\ textAlign: 'right'," $pvemanagerlib

    ###################  修改proxmoxlib.js   ##########################

    log_info "加强去除订阅弹窗"
    # 调用 remove_subscription_popup 函数，避免重复代码
    remove_subscription_popup

    # 显示修改结果
    # sed -n '/\/nodes\/localhost\/subscription/,+10p' $proxmoxlib >> /var/log/pve-tools.log
    systemctl restart pveproxy

    log_success "请刷新浏览器缓存shift+f5"
}
cpu_del() {
    local nodes="/usr/share/perl5/PVE/API2/Nodes.pm"
    local pvemanagerlib="/usr/share/pve-manager/js/pvemanagerlib.js"
    local proxmoxlib="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    local pvever

    pvever=$(pveversion | awk -F"/" '{print $2}')
    log_step "Restore official node overview files"
    log_warn "This will remove the temperature patch and reinstall official pve-manager / proxmox-widget-toolkit files"

    if ! confirm_action "Restore official node overview files?"; then
        return
    fi

    if reinstall_pve_webui_packages; then
        rm -f "$nodes.$pvever.bak" "$pvemanagerlib.$pvever.bak" "$proxmoxlib.$pvever.bak"
        log_success "Official node overview files restored. Use Shift+F5 to refresh browser cache."
    fi
}
#--------------CPU、主板、硬盘温度显示----------------

#--------------GRUB 配置管理工具----------------
# 展示当前 GRUB 配置
show_grub_config() {
    log_info "当前 GRUB 配置信息"
    echo "$UI_DIVIDER"

    if [ ! -f "/etc/default/grub" ]; then
        log_error "未找到 /etc/default/grub 文件"
        return 1
    fi

    log_info "文件路径: ${CYAN}/etc/default/grub${NC}"
    log_info "当前内核参数:"

    # 读取并显示 GRUB_CMDLINE_LINUX_DEFAULT
    current_config=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | sed 's/GRUB_CMDLINE_LINUX_DEFAULT=//' | tr -d '"')

    if [ -z "$current_config" ]; then
        log_warn "未找到 GRUB_CMDLINE_LINUX_DEFAULT 配置"
    else
        log_success "GRUB_CMDLINE_LINUX_DEFAULT 内容:"
        # 逐行显示参数
        echo "$current_config" | tr ' ' '\n' | while read -r param; do
            [ -n "$param" ] && echo -e "  ${BLUE}•${NC} $param"
        done
    fi

    echo "$UI_DIVIDER"

    # 检测关键参数
    log_info "关键参数检测:"

    # 检测 IOMMU
    if echo "$current_config" | grep -q "intel_iommu=on\|amd_iommu=on"; then
        echo -e "  ${GREEN}[ OK ]${NC} IOMMU: 已启用"
    else
        echo -e "  ${YELLOW}[WARN]${NC} IOMMU: 未启用"
    fi

    # 检测 SR-IOV
    if echo "$current_config" | grep -q "i915.enable_guc=3"; then
        echo -e "  ${GREEN}[ OK ]${NC} SR-IOV: 已配置"
    else
        echo -e "  ${BLUE}[INFO]${NC} SR-IOV: 未配置"
    fi

    # 检测 GVT-g
    if echo "$current_config" | grep -q "i915.enable_gvt=1"; then
        echo -e "  ${GREEN}[ OK ]${NC} GVT-g: 已配置"
    else
        echo -e "  ${BLUE}[INFO]${NC} GVT-g: 未配置"
    fi

    # 检测硬件直通
    if echo "$current_config" | grep -q "iommu=pt"; then
        echo -e "  ${GREEN}[ OK ]${NC} 硬件直通: 已启用"
    else
        echo -e "  ${BLUE}[INFO]${NC} 硬件直通: 未启用"
    fi

    echo "$UI_DIVIDER"
}

# GRUB 配置备份
backup_grub_with_note() {
    local note="$1"
    local backup_dir="/etc/pvetools9/backup/grub"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="${backup_dir}/${timestamp}_${note}.bak"

    log_step "备份 GRUB 配置..."

    # 创建备份目录
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir" || {
            log_error "无法创建备份目录: $backup_dir"
            return 1
        }
        log_info "创建备份目录: $backup_dir"
    fi

    # 检查源文件
    if [ ! -f "/etc/default/grub" ]; then
        log_error "源文件不存在: /etc/default/grub"
        return 1
    fi

    # 执行备份
    cp "/etc/default/grub" "$backup_file" || {
        log_error "备份失败"
        return 1
    }

    log_success "GRUB 配置已备份"
    log_info "备份文件: $backup_file"
    log_info "备份时间: $(date '+%Y-%m-%d %H:%M:%S')"
    log_info "备份备注: $note"

    # 统计备份文件数量
    local backup_count=$(ls -1 "$backup_dir"/*.bak 2>/dev/null | wc -l)
    log_info "当前共有 $backup_count 个备份文件"

    return 0
}

# 列出所有 GRUB 备份
list_grub_backups() {
    local backup_dir="/etc/pvetools9/backup/grub"

    log_info "GRUB 配置备份列表"
    log_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ ! -d "$backup_dir" ]; then
        log_warn "备份目录不存在: $backup_dir"
        log_tips "尚未创建任何备份"
        return 0
    fi

    local backup_files=$(ls -1t "$backup_dir"/*.bak 2>/dev/null)

    if [ -z "$backup_files" ]; then
        log_warn "未找到任何备份文件"
        return 0
    fi

    local count=1
    echo "$backup_files" | while read -r backup_file; do
        local filename=$(basename "$backup_file")
        local filesize=$(du -h "$backup_file" | awk '{print $1}')
        local filetime=$(stat -c '%y' "$backup_file" 2>/dev/null || stat -f '%Sm' "$backup_file")

        log_info "备份 $count:"
        log_info "  文件名: $filename"
        log_info "  大小: $filesize"
        log_info "  时间: $filetime"
        log_step "  ────────────────────────────────────"

        count=$((count + 1))
    done

    log_step "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 恢复 GRUB 备份
restore_grub_backup() {
    local backup_dir="/etc/pvetools9/backup/grub"

    list_grub_backups

    if [ ! -d "$backup_dir" ] || [ -z "$(ls -A "$backup_dir"/*.bak 2>/dev/null)" ]; then
        log_error "没有可恢复的备份文件"
        pause_function
        return 1
    fi

    echo
    log_warn "请输入要恢复的备份文件名（完整文件名）:"
    read -p "> " backup_filename

    local backup_file="${backup_dir}/${backup_filename}"

    if [ ! -f "$backup_file" ]; then
        log_error "备份文件不存在: $backup_filename"
        pause_function
        return 1
    fi

    log_warn "即将恢复 GRUB 配置"
    log_info "源文件: $backup_file"
    log_info "目标文件: /etc/default/grub"

    if ! confirm_action "确认恢复此备份"; then
        log_info "用户取消恢复操作"
        return 0
    fi

    # 在恢复前备份当前配置
    backup_grub_with_note "恢复前自动备份"

    # 执行恢复
    cp "$backup_file" "/etc/default/grub" || {
        log_error "恢复失败"
        pause_function
        return 1
    }

    log_success "GRUB 配置已恢复"

    # 更新 GRUB
    if confirm_action "是否立即更新 GRUB"; then
        update-grub && log_success "GRUB 更新完成" || log_error "GRUB 更新失败"
    fi

    pause_function
}
#--------------GRUB 配置管理工具----------------

#--------------核显虚拟化管理----------------
# 核显管理菜单
# 简化版核显虚拟化菜单（保留用于兼容性）

import 'dart:convert';
import 'dart:io';

import 'package:qinglong_app/utils/extension.dart';
import 'package:qinglong_app/utils/sp_utils.dart';

import 'sp_const.dart';
import 'userinfo_viewmodel.dart';

class MultiAccountUserInfoViewModel {
  static int maxAccount = 1; //1代表普通用户, 5代表付费用户

  List<TokenBean> tokenBeans = [];
  List<UserInfoBean> historyAccounts = [];

  static void payedVIP(int type) {
    if (SpUtil.getInt(spVIP, defValue: typeNormal) == typeSVIP) return;

    SpUtil.putInt(spVIP, type);

    int count = 1;
    if (type == typeNormal) {
      count = 1;
    } else if (type == typeVIP) {
      count = 3;
    } else if (type == typeSVIP) {
      count = 5;
    }
    SpUtil.putInt(spAccountCount, count);
  }

  static void updateMaxAccount(int count) {

    SpUtil.putInt(spAccountCount, count);
  }

  MultiAccountUserInfoViewModel() {
    try {
      List<dynamic>? tempTokenList = jsonDecode(SpUtil.getString(spTokenBeanList, defValue: '[]'));

      if (tempTokenList != null && tempTokenList.isNotEmpty) {
        for (Map<String, dynamic> value in tempTokenList) {
          //把token里的空数据拿出
          var bean = TokenBean.fromJson(value);
          if (bean.host == null && bean.token == null) continue;
          tokenBeans.add(TokenBean.fromJson(value));
        }
      }

      List<dynamic>? tempList = jsonDecode(SpUtil.getString(spLoginHistory, defValue: '[]'));

      if (tempList != null && tempList.isNotEmpty) {
        for (Map<String, dynamic> value in tempList) {
          historyAccounts.add(UserInfoBean.fromJson(value));
        }
      }
    } catch (e) {
      e.toString().toast2();
    }
  }

  void initVipState() {
    int vipType = SpUtil.getInt(spVIP, defValue: typeNormal);

    if (vipType == typeNormal) {
      maxAccount = 1;
    } else if (vipType == typeVIP) {
      maxAccount = 3;
    } else {
      maxAccount = SpUtil.getInt(spAccountCount, defValue: 5);
    }
  }

  /// 地址归一化：去 scheme、去尾部斜杠、小写，用于宽松比对历史账号
  static String _normHost(String? raw) {
    var h = (raw ?? '').trim().toLowerCase();
    if (h.startsWith('https://')) h = h.substring(8);
    if (h.startsWith('http://')) h = h.substring(7);
    while (h.endsWith('/')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// 按 host 查找历史账号（本地凭证来源）
  ///
  /// 依次尝试：精确匹配 → 归一化地址匹配 → 只有一个历史账号时兜底。
  /// 早期版本未记住密码、或地址写法不同（带/不带 http://、IPv6 方括号）
  /// 时精确匹配会失败，导致「静默重新登录」永远拿不到账号密码。
  UserInfoBean? findHistoryAccount(String? host) {
    if (historyAccounts.isEmpty) return null;

    final String h = (host ?? '').trim();
    if (h.isNotEmpty) {
      for (final bean in historyAccounts) {
        if (bean.host == h) return bean;
      }
      final String target = _normHost(h);
      for (final bean in historyAccounts) {
        if (_normHost(bean.host) == target) return bean;
      }
    }

    if (historyAccounts.length == 1) return historyAccounts.first;
    return null;
  }

  void save2HistoryAccount(UserInfoBean userInfoBean) {
    //如果已经存在host，那就更�?

    historyAccounts.removeWhere((element) => element.host == userInfoBean.host);

    historyAccounts.insert(
      0,
      userInfoBean,
    );

    SpUtil.putString(spLoginHistory, jsonEncode(historyAccounts));
  }

  void removeHistoryAccount(String? host) {
    if (host == null || host.isEmpty) return;

    historyAccounts.removeWhere((element) => element.host == host);

    SpUtil.putString(spLoginHistory, jsonEncode(historyAccounts));
  }

  void updateToken(int index, String? host, String? token, bool useSecretLogined, String? alias) {
    if (host == null) return;

    if (MultiAccountUserInfoViewModel.maxAccount == 1) {
      tokenBeans.clear();
      tokenBeans.add(
        TokenBean(
          token: token,
          host: host,
          useSecretLogined: useSecretLogined,
          alias: alias,
        ),
      );
    } else {
      if (tokenBeans.length <= index) {
        tokenBeans.add(
          TokenBean(
            token: token,
            host: host,
            useSecretLogined: useSecretLogined,
            alias: alias,
          ),
        );
      } else {
        tokenBeans[index].token = token;
        tokenBeans[index].useSecretLogined = useSecretLogined;
        tokenBeans[index].alias = alias;
        tokenBeans[index].host = host;
      }
    }
    SpUtil.putString(spTokenBeanList, jsonEncode(tokenBeans));
  }

  void removeTokenBean(int index) {
    tokenBeans[index].token = null;
    tokenBeans[index].host = null;
    tokenBeans[index].alias = null;
    tokenBeans[index].useSecretLogined = false;
    SpUtil.putString(spTokenBeanList, jsonEncode(tokenBeans));
  }

  /// 更新指定账号的别名，同时持久化到 tokenBeans 和 historyAccounts。
  /// 仅按 host 匹配更新别名，不改变 historyAccounts 的顺序。
  /// 用于「修改名称」场景，确保两份存储同步，避免重启后丢失。
  void updateAliasForHost(String? host, String? alias) {
    if (host == null || host.isEmpty) return;

    bool tokenChanged = false;
    for (var bean in tokenBeans) {
      if (bean.host == host) {
        bean.alias = alias;
        tokenChanged = true;
      }
    }
    if (tokenChanged) {
      SpUtil.putString(spTokenBeanList, jsonEncode(tokenBeans));
    }

    bool historyChanged = false;
    for (var bean in historyAccounts) {
      if (bean.host == host) {
        bean.alias = alias;
        historyChanged = true;
      }
    }
    if (historyChanged) {
      SpUtil.putString(spLoginHistory, jsonEncode(historyAccounts));
    }
  }

  void resetTokenBeans(List<TokenBean> bean) {
    SpUtil.putString(spTokenBeanList, jsonEncode(bean));
    tokenBeans.clear();
    tokenBeans.addAll(bean);
  }
}

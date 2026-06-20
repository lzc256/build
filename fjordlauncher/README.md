# FjordLauncher Patches

## Patches

### 01-remove-msa-requirement

移除添加离线账户和 authlib-injector 账户时需要微软账户的限制。

**修改内容:**
- 删除 `on_actionAddAuthlibInjector_triggered()` 中的 `anyAccountIsValid()` 检查
- 删除 `on_actionAddOffline_triggered()` 中的 `anyAccountIsValid()` 检查

**效果:**
- 无需微软账户即可添加离线账户
- 无需微软账户即可添加自定义认证服务器账户

**原始代码位置:** `launcher/ui/pages/global/AccountListPage.cpp`

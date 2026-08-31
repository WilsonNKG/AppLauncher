part of '../main.dart';

/// Staff access, role catalog, and permission actions for the launcher state.
extension _StaffManagementWorkspace on _LauncherPageState {
  void _showStaffManagement() {
    var staffFuture = _loadAllStaffForAdmin();
    var searchQuery = '';
    final searchController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            _text(dialogContext, 'Staff management', 'Manajemen staf'),
          ),
          content: SizedBox(
            width: 700,
            height: 560,
            child: Column(
              children: [
                TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: _text(
                      dialogContext,
                      'Search by email or role',
                      'Cari berdasarkan email atau peran',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              searchController.clear();
                              setDialogState(() => searchQuery = '');
                            },
                          ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setDialogState(() {
                    searchQuery = value.trim().toLowerCase();
                  }),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<StaffMember>>(
                    future: staffFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _text(
                                context,
                                'Unable to load staff.',
                                'Tidak dapat memuat staf.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => setDialogState(() {
                                staffFuture = _loadAllStaffForAdmin();
                              }),
                              icon: const Icon(Icons.refresh),
                              label: Text(_text(context, 'Retry', 'Coba lagi')),
                            ),
                          ],
                        );
                      }
                      final staff = snapshot.data ?? [];
                      final filteredStaff = staff.where((member) {
                        if (searchQuery.isEmpty) return true;
                        return member.email.toLowerCase().contains(
                              searchQuery,
                            ) ||
                            member.roles.any(
                              (role) =>
                                  role.toLowerCase().contains(searchQuery),
                            );
                      }).toList();
                      if (filteredStaff.isEmpty) {
                        return Center(
                          child: Text(
                            staff.isEmpty
                                ? _text(
                                    context,
                                    'No staff found.',
                                    'Staf belum ada.',
                                  )
                                : _text(
                                    context,
                                    'No staff matches your search.',
                                    'Tidak ada staf yang cocok dengan pencarian.',
                                  ),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(
                              context,
                              '${filteredStaff.length} staff member${filteredStaff.length == 1 ? '' : 's'}',
                              '${filteredStaff.length} staf',
                            ),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.separated(
                              itemCount: filteredStaff.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final member = filteredStaff[index];
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    child: Text(
                                      member.email
                                          .substring(0, 1)
                                          .toUpperCase(),
                                    ),
                                  ),
                                  title: Text(member.email),
                                  subtitle: Text(
                                    member.roles.isEmpty
                                        ? _text(
                                            context,
                                            'No roles assigned',
                                            'Belum ada peran',
                                          )
                                        : member.roles.join(', '),
                                  ),
                                  trailing: IconButton(
                                    tooltip: _text(
                                      context,
                                      'Edit access',
                                      'Edit akses',
                                    ),
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () async {
                                      await _showEditStaffAccess(member);
                                      if (dialogContext.mounted) {
                                        setDialogState(() {
                                          staffFuture = _loadAllStaffForAdmin();
                                        });
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => setDialogState(() {
                staffFuture = _loadAllStaffForAdmin();
              }),
              icon: const Icon(Icons.refresh),
              label: Text(_text(dialogContext, 'Refresh', 'Muat ulang')),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Close', 'Tutup')),
            ),
          ],
        ),
      ),
    ).then((_) => searchController.dispose());
  }

  Future<List<StaffRole>> _loadAllRolesForAdmin() async {
    final response = await Supabase.instance.client.rpc(
      'get_all_roles_for_admin',
    );
    return (response as List<dynamic>)
        .map((row) => StaffRole.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> _showEditStaffAccess(StaffMember member) async {
    final rolesFuture = _loadAllRolesForAdmin();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            _text(
              dialogContext,
              'Edit access · ${member.email}',
              'Edit akses · ${member.email}',
            ),
          ),
          content: SizedBox(
            width: 760,
            height: 560,
            child: FutureBuilder<List<StaffRole>>(
              future: rolesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text(
                    _text(
                      context,
                      'Unable to load roles.',
                      'Tidak dapat memuat peran.',
                    ),
                  );
                }
                final roles = snapshot.data ?? [];
                final groupedRoles = <String, List<StaffRole>>{};
                for (final role in roles) {
                  final category = role.appName ?? 'NKG App';
                  groupedRoles.putIfAbsent(category, () => []).add(role);
                }
                final roleWidgets = <Widget>[];
                final sections = [
                  ..._staffRoleSectionOrder,
                  ...groupedRoles.keys.where(
                    (key) => !_staffRoleSectionOrder.contains(key),
                  ),
                ];
                for (final section in sections) {
                  final sectionRoles = groupedRoles[section] ?? const [];
                  final configured = sectionRoles.isNotEmpty;
                  roleWidgets.add(
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        section,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _staffRoleSectionDescription(
                                          context,
                                          section,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    configured
                                        ? '${sectionRoles.length} ${_text(context, 'roles', 'peran')}'
                                        : _text(
                                            context,
                                            'Coming later',
                                            'Segera hadir',
                                          ),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (!configured)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Text(
                                  _text(
                                    context,
                                    'Role catalog is not configured yet.',
                                    'Katalog peran belum dikonfigurasi.',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              )
                            else
                              ...sectionRoles.map((role) {
                                final selected = member.roleIds.contains(
                                  role.id,
                                );
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  value: selected,
                                  title: Text(
                                    role.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: Text(
                                    role.description.isEmpty
                                        ? '${_text(context, 'App access', 'Akses aplikasi')}: ${role.appAccess}'
                                        : '${role.description}\n${_text(context, 'App access', 'Akses aplikasi')}: ${role.appAccess}',
                                  ),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      if (value == true) {
                                        member.roleIds.add(role.id);
                                      } else {
                                        member.roleIds.remove(role.id);
                                      }
                                    });
                                  },
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return ListView(children: roleWidgets);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Cancel', 'Batal')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.rpc(
                    'set_user_roles_for_admin',
                    params: {
                      'p_user_id': member.userId,
                      'p_role_ids': member.roleIds,
                    },
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                } catch (_) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          _text(
                            dialogContext,
                            'Unable to update access.',
                            'Tidak dapat memperbarui akses.',
                          ),
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text(_text(dialogContext, 'Save', 'Simpan')),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<LauncherApp>> _loadAllAppsForAdmin() async {
    final response = await Supabase.instance.client.rpc(
      'get_all_launcher_apps_for_admin',
    );
    return (response as List<dynamic>)
        .map((row) => LauncherApp.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<List<StaffMember>> _loadAllStaffForAdmin() async {
    final response = await Supabase.instance.client.rpc(
      'get_all_staff_for_admin',
    );
    return (response as List<dynamic>)
        .map((row) => StaffMember.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  // Kept as a compatibility entry point for existing callers.
  // ignore: unused_element
  Future<void> _showRoleManagement(LauncherApp app) async {
    var rolesFuture = _loadAllRolesForAdmin();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            '${_text(dialogContext, 'Role management', 'Manajemen peran')} · ${app.name}',
          ),
          content: SizedBox(
            width: 620,
            height: 480,
            child: FutureBuilder<List<StaffRole>>(
              future: rolesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text(snapshot.error.toString()));
                }
                final roles = (snapshot.data ?? [])
                    .where((role) => role.appName == app.name)
                    .toList();
                return ListView.separated(
                  itemCount: roles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(role.name.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(
                          role.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${role.description}\n${_text(context, 'Permissions', 'Izin')}: ${role.permissionKeys.isEmpty ? _text(context, 'None', 'Tidak ada') : role.permissionKeys.join(', ')}',
                        ),
                        isThreeLine: true,
                        trailing: OutlinedButton(
                          onPressed: () async {
                            await _showRolePermissionEditor(app, role);
                            if (dialogContext.mounted) {
                              setDialogState(
                                () => rolesFuture = _loadAllRolesForAdmin(),
                              );
                            }
                          },
                          child: Text(_text(context, 'Permissions', 'Izin')),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () async {
                if (await _showCreateCustomRole(app) && dialogContext.mounted) {
                  setDialogState(() => rolesFuture = _loadAllRolesForAdmin());
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                _text(dialogContext, 'Create custom role', 'Buat peran khusus'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_text(dialogContext, 'Close', 'Tutup')),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCreateCustomRole(LauncherApp app) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          _text(dialogContext, 'Create custom role', 'Buat peran khusus'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: _text(dialogContext, 'Role name', 'Nama peran'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: _text(
                  dialogContext,
                  'What can this role do?',
                  'Apa yang dapat dilakukan peran ini?',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(_text(dialogContext, 'Cancel', 'Batal')),
          ),
          FilledButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await Supabase.instance.client.rpc(
                  'create_custom_role_for_admin',
                  params: {
                    'p_app_id': app.id,
                    'p_role_name': nameController.text.trim(),
                    'p_description': descriptionController.text.trim(),
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(
                    dialogContext,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              }
            },
            child: Text(_text(dialogContext, 'Create', 'Buat')),
          ),
        ],
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    return created ?? false;
  }

  Future<void> _showRolePermissionEditor(
    LauncherApp app,
    StaffRole role,
  ) async {
    final selected = role.permissionKeys.toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(
            '${role.name} · ${_text(dialogContext, 'Permissions', 'Izin')}',
          ),
          content: app.permissions.isEmpty
              ? Text(
                  _text(
                    dialogContext,
                    'No permissions are defined for this app yet.',
                    'Belum ada izin untuk aplikasi ini.',
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: app.permissions.map((permission) {
                      return CheckboxListTile(
                        value: selected.contains(permission),
                        title: Text(permission),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selected.add(permission);
                          } else {
                            selected.remove(permission);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(_text(dialogContext, 'Cancel', 'Batal')),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.rpc(
                    'set_role_permissions_for_admin',
                    params: {
                      'p_role_id': role.id,
                      'p_permission_keys': selected.toList(),
                    },
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                }
              },
              child: Text(_text(dialogContext, 'Save', 'Simpan')),
            ),
          ],
        ),
      ),
    );
  }
}

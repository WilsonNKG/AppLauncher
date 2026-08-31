part of '../main.dart';

class _RoleMetric extends StatelessWidget {
  const _RoleMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoleManagementWorkspace extends NkgWorkspace {
  const RoleManagementWorkspace({
    required this.apps,
    required this.loadRoles,
    required this.onCreateRole,
    required this.onEditPermissions,
    this.initialRoles,
    super.key,
  });

  final List<LauncherApp> apps;
  final Future<List<StaffRole>> Function() loadRoles;
  final Future<List<StaffRole>>? initialRoles;
  final Future<void> Function() onCreateRole;
  final Future<void> Function(LauncherApp app, StaffRole role)
  onEditPermissions;

  @override
  State<RoleManagementWorkspace> createState() =>
      _RoleManagementWorkspaceState();
}

class _RoleManagementWorkspaceState extends State<RoleManagementWorkspace> {
  late Future<List<StaffRole>> _roles;
  String _filter = 'All applications';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _roles = widget.initialRoles ?? widget.loadRoles();
  }

  void _refresh() => setState(() => _roles = widget.loadRoles());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_text(context, 'Role Management', 'Manajemen Peran')),
        centerTitle: false,
        actions: [
          OutlinedButton.icon(
            onPressed: () async {
              await widget.onCreateRole();
              if (mounted) _refresh();
            },
            icon: const Icon(Icons.add),
            label: Text(_text(context, 'Custom role', 'Peran khusus')),
          ),
          const SizedBox(width: 20),
        ],
      ),
      body: FutureBuilder<List<StaffRole>>(
        future: _roles,
        builder: (context, snapshot) {
          final allRoles = snapshot.data ?? const <StaffRole>[];
          final roles = allRoles.where((role) {
            final appName = role.appName ?? 'NKG App';
            final query = _search.toLowerCase().trim();
            return (_filter == 'All applications' || appName == _filter) &&
                (query.isEmpty ||
                    appName.toLowerCase().contains(query) ||
                    role.name.toLowerCase().contains(query) ||
                    role.description.toLowerCase().contains(query));
          }).toList();
          final filters = <String>[
            'All applications',
            ...{...allRoles.map((role) => role.appName ?? 'NKG App')},
          ];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(40, 34, 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _text(
                    context,
                    'Access governance workspace',
                    'Workspace tata kelola akses',
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _text(
                    context,
                    'Control role capabilities across the NKG ecosystem from one place.',
                    'Kelola kemampuan peran di seluruh ekosistem NKG dari satu tempat.',
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    _RoleMetric(
                      label: _text(context, 'Total roles', 'Total peran'),
                      value: '${allRoles.length}',
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(width: 16),
                    _RoleMetric(
                      label: _text(context, 'Applications', 'Aplikasi'),
                      value: '${filters.length - 1}',
                      icon: Icons.apps_outlined,
                    ),
                    const SizedBox(width: 16),
                    _RoleMetric(
                      label: _text(context, 'Permission rules', 'Aturan izin'),
                      value:
                          '${allRoles.fold<int>(0, (sum, role) => sum + role.permissionKeys.length)}',
                      icon: Icons.rule_folder_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    SizedBox(
                      width: 320,
                      child: TextField(
                        onChanged: (value) => setState(() => _search = value),
                        decoration: InputDecoration(
                          hintText: _text(
                            context,
                            'Search roles or apps',
                            'Cari peran atau aplikasi',
                          ),
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    DropdownButton<String>(
                      value: filters.contains(_filter)
                          ? _filter
                          : filters.first,
                      items: filters
                          .map(
                            (filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _filter = value ?? filters.first),
                    ),
                    const Spacer(),
                    Text(
                      '${roles.length} ${_text(context, 'roles shown', 'peran ditampilkan')}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    margin: EdgeInsets.zero,
                    child: roles.isEmpty
                        ? Center(
                            child: Text(
                              _text(
                                context,
                                'No roles found.',
                                'Peran tidak ditemukan.',
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: SizedBox(
                              width: double.infinity,
                              child: DataTable(
                                columnSpacing: 34,
                                dataRowMinHeight: 76,
                                dataRowMaxHeight: 96,
                                headingRowColor: WidgetStatePropertyAll(
                                  Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                ),
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      _text(context, 'Application', 'Aplikasi'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      _text(context, 'Role', 'Peran'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      _text(context, 'Capability', 'Kemampuan'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      _text(context, 'Permissions', 'Izin'),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      _text(context, 'Action', 'Aksi'),
                                    ),
                                  ),
                                ],
                                rows: roles.map((role) {
                                  final app = widget.apps
                                      .where(
                                        (item) => item.name == role.appName,
                                      )
                                      .firstOrNull;
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(role.appName ?? 'NKG App')),
                                      DataCell(
                                        Text(
                                          role.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        SizedBox(
                                          width: 260,
                                          child: Text(
                                            role.description.isEmpty
                                                ? role.appAccess
                                                : role.description,
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          role.permissionKeys.isEmpty
                                              ? '—'
                                              : role.permissionKeys.join(', '),
                                        ),
                                      ),
                                      DataCell(
                                        OutlinedButton(
                                          onPressed: app == null
                                              ? null
                                              : () async {
                                                  await widget
                                                      .onEditPermissions(
                                                        app,
                                                        role,
                                                      );
                                                  if (mounted) _refresh();
                                                },
                                          child: Text(
                                            _text(context, 'Edit', 'Edit'),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

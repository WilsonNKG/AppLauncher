part of '../main.dart';

/// Application catalog and application availability administration.
extension _AppManagementWorkspace on _LauncherPageState {
  void _showAppManagement() {
    var appsFuture = _loadAllAppsForAdmin();
    String? updatingAppId;
    var availableFirst = true;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                  _text(dialogContext, 'App management', 'Manajemen aplikasi'),
                ),
              ),
              IconButton(
                tooltip: availableFirst
                    ? _text(
                        dialogContext,
                        'Sorted: available first',
                        'Urutan: tersedia lebih dulu',
                      )
                    : _text(
                        dialogContext,
                        'Sorted: paused first',
                        'Urutan: dijeda lebih dulu',
                      ),
                icon: const Icon(Icons.sort_rounded),
                onPressed: () =>
                    setDialogState(() => availableFirst = !availableFirst),
              ),
            ],
          ),
          content: SizedBox(
            width: 700,
            height: 500,
            child: FutureBuilder<List<LauncherApp>>(
              future: appsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _text(
                          context,
                          'Unable to load applications.',
                          'Tidak dapat memuat aplikasi.',
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
                          appsFuture = _loadAllAppsForAdmin();
                        }),
                        icon: const Icon(Icons.refresh),
                        label: Text(_text(context, 'Retry', 'Coba lagi')),
                      ),
                    ],
                  );
                }
                final apps = [...?snapshot.data]
                  ..sort((a, b) {
                    final aRank = a.status == 'active' ? 0 : 1;
                    final bRank = b.status == 'active' ? 0 : 1;
                    return (availableFirst ? aRank - bRank : bRank - aRank);
                  });
                if (_roleWorkspaceActive) {
                  return _buildRoleManagementWorkspace(apps);
                }
                if (apps.isEmpty) {
                  return Center(
                    child: Text(
                      _text(
                        context,
                        'No applications have been configured yet.',
                        'Belum ada aplikasi yang dikonfigurasi.',
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: apps.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final active = app.status == 'active';
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: active
                                  ? Colors.green.withValues(alpha: .12)
                                  : Colors.orange.withValues(alpha: .12),
                              child: Icon(
                                Icons.apps_rounded,
                                color: active
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    app.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(app.description),
                                  const SizedBox(height: 6),
                                  Text(
                                    app.launchUrl,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _text(
                                      context,
                                      '${app.permissions.length} access permission${app.permissions.length == 1 ? '' : 's'}',
                                      '${app.permissions.length} izin akses',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelMedium,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                Chip(
                                  label: Text(
                                    active
                                        ? _text(
                                            context,
                                            'Available',
                                            'Tersedia',
                                          )
                                        : _text(context, 'Paused', 'Dijeda'),
                                  ),
                                  backgroundColor: active
                                      ? Colors.green.withValues(alpha: .12)
                                      : Colors.orange.withValues(alpha: .12),
                                ),
                                Switch(
                                  value: active,
                                  onChanged: updatingAppId == app.id
                                      ? null
                                      : (enabled) async {
                                          setDialogState(() {
                                            updatingAppId = app.id;
                                          });
                                          try {
                                            await Supabase.instance.client.rpc(
                                              'set_launcher_app_status',
                                              params: {
                                                'p_app_id': app.id,
                                                'p_status': enabled
                                                    ? 'active'
                                                    : 'paused',
                                              },
                                            );
                                            setDialogState(
                                              () => appsFuture =
                                                  _loadAllAppsForAdmin(),
                                            );
                                            _refreshLauncherApps(_loadApps());
                                          } catch (error) {
                                            // Some PostgREST versions report a
                                            // response error after committing
                                            // the update. Verify the stored
                                            // value before showing a failure.
                                            try {
                                              final refreshed =
                                                  await _loadAllAppsForAdmin();
                                              final updated = refreshed
                                                  .where(
                                                    (item) => item.id == app.id,
                                                  )
                                                  .toList();
                                              if (updated.isNotEmpty &&
                                                  updated.first.status ==
                                                      (enabled
                                                          ? 'active'
                                                          : 'paused')) {
                                                setDialogState(() {
                                                  appsFuture = Future.value(
                                                    refreshed,
                                                  );
                                                });
                                                _refreshLauncherApps(
                                                  Future.value(refreshed),
                                                );
                                                return;
                                              }
                                            } catch (_) {
                                              // Fall through to the real error.
                                            }
                                            if (dialogContext.mounted) {
                                              ScaffoldMessenger.of(
                                                dialogContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    _text(
                                                      dialogContext,
                                                      'Unable to update application status: $error',
                                                      'Tidak dapat memperbarui status aplikasi: $error',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          } finally {
                                            if (dialogContext.mounted) {
                                              setDialogState(() {
                                                updatingAppId = null;
                                              });
                                            }
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_text(dialogContext, 'Close', 'Tutup')),
            ),
          ],
        ),
      ),
    );
  }
}

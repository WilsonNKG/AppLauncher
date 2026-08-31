import 'package:flutter/material.dart';

/// Common contract for full-page NKG workspaces.
///
/// Each workspace owns its page layout and state instead of being rendered as
/// a dialog from the launcher.
abstract class NkgWorkspace extends StatefulWidget {
  const NkgWorkspace({super.key});
}

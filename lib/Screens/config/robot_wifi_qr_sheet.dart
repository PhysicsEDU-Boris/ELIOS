import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/robot_wifi.dart';
import '../../theme/elio_theme.dart';
import '../../theme/elio_tokens.dart';
import '../../widgets/learn/learn_ui.dart';
import 'config_parts.dart';
import 'package:elio/l10n/l10n.dart';

Future<void> showRobotWifiQrSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ElioTheme.wrap(const RobotWifiQrSheet()),
    );

/// Hotspot name + password in, a Wi-Fi QR out for the robot's "Wi-Fi setup"
/// screen (decision 0178). Nothing is saved: the password lives only in this sheet.
class RobotWifiQrSheet extends StatefulWidget {
  const RobotWifiQrSheet({super.key});

  @override
  State<RobotWifiQrSheet> createState() => _RobotWifiQrSheetState();
}

class _RobotWifiQrSheetState extends State<RobotWifiQrSheet> {
  final _form = GlobalKey<FormState>();
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  bool _hidePass = true;
  String? _qr;

  @override
  void dispose() {
    _ssid.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _show() {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _qr = wifiQrPayload(_ssid.text, _pass.text));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(learnRadiusXl)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const ConfigIconChip(Icons.qr_code_2_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(context.l10n.robotWifiQr,
                            style: ElioTokens.bodyLarge.copyWith(
                                fontSize: 22, fontWeight: FontWeight.w700, color: p.textPrimary)),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.commonClose,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: p.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.qrIntro,
                  style: configCaption(p),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ssid,
                  validator: validateWifiName,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.qrSsid,
                    prefixIcon: Icon(Icons.wifi_tethering_rounded),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _qr = null),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pass,
                  validator: validateWifiPassword,
                  obscureText: _hidePass,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) => _show(),
                  decoration: InputDecoration(
                    labelText: l10n.qrPassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _hidePass ? l10n.qrShowPassword : l10n.qrHidePassword,
                      onPressed: () => setState(() => _hidePass = !_hidePass),
                      icon: Icon(_hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  onChanged: (_) => setState(() => _qr = null),
                ),
                const SizedBox(height: 16),
                ConfigButton(label: l10n.qrShow, icon: Icons.qr_code_2_rounded, onPressed: _show),
                if (_qr != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Semantics(
                      label: l10n.qrSemantics(_ssid.text),
                      image: true,
                      child: Container(
                        // White with a quiet zone so the camera reads it in dark mode too.
                        color: Colors.white,
                        padding: const EdgeInsets.all(16),
                        child: SvgPicture.string(Barcode.qrCode().toSvg(_qr!, width: 260, height: 260)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.robotQrHint,
                      textAlign: TextAlign.center, style: configCaption(p)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../services/robot_wifi.dart';
import '../../theme/elio_motion.dart';
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
/// screen (decision 0178; ELIOS 3 look 0204, Figma 629:91020 / 629:91453).
/// Nothing is saved: the password lives only in this sheet.
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

  /// Figma "Config / Input field" 337:2481: caption label above a 48 dp field.
  Widget _field(ElioPalette p, String label, Widget field) => MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: configCaption(p).copyWith(fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            field,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.elio;
    final caption = configCaption(p).copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(learnRadiusXl)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle (the sheet is drag-dismissible).
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: ShapeDecoration(color: p.borderMedium, shape: const StadiumBorder()),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(
                    children: [
                      ConfigIconChip(
                        Icons.qr_code_2_rounded,
                        size: 44,
                        // Figma chip/success-bg: 6 % green on light, 12 % on dark.
                        background: p.isDark
                            ? p.primary.withValues(alpha: 0.12)
                            : p.primaryActive.withValues(alpha: 0.06),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l10n.robotWifiQr,
                                  style: ElioTokens.headline.copyWith(color: p.textPrimary)),
                              Text(l10n.robotWifiQrSubtitle, style: caption),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElioPress(
                        child: IconButton(
                          tooltip: l10n.commonClose,
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: p.surface,
                            minimumSize: const Size.square(48),
                            side: BorderSide(color: p.borderSubtle),
                          ),
                          icon: Icon(Icons.close_rounded, size: 22, color: p.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.qrIntro, style: caption),
                      const SizedBox(height: 20),
                      _field(
                        p,
                        l10n.qrSsid,
                        TextFormField(
                          controller: _ssid,
                          validator: validateWifiName,
                          textInputAction: TextInputAction.next,
                          autocorrect: false,
                          style: ElioTokens.body.copyWith(color: p.textPrimary),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.wifi_rounded, size: 20),
                          ),
                          onChanged: (_) => setState(() => _qr = null),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _field(
                        p,
                        l10n.qrPassword,
                        TextFormField(
                          controller: _pass,
                          validator: validateWifiPassword,
                          obscureText: _hidePass,
                          autocorrect: false,
                          enableSuggestions: false,
                          onFieldSubmitted: (_) => _show(),
                          style: ElioTokens.body.copyWith(color: p.textPrimary),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                            suffixIcon: IconButton(
                              tooltip: _hidePass ? l10n.qrShowPassword : l10n.qrHidePassword,
                              onPressed: () => setState(() => _hidePass = !_hidePass),
                              icon: Icon(_hidePass ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            ),
                          ),
                          onChanged: (_) => setState(() => _qr = null),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElioPress(
                        child: ConfigButton(label: l10n.qrShow, icon: Icons.qr_code_2_rounded, onPressed: _show),
                      ),
                      if (_qr != null) ...[
                        const SizedBox(height: 20),
                        ElioPopIn(
                          key: ValueKey(_qr),
                          child: Semantics(
                            label: l10n.qrSemantics(_ssid.text),
                            image: true,
                            child: Container(
                              // Always black-on-white with a quiet zone so the camera reads it in dark mode too.
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.string(Barcode.qrCode().toSvg(_qr!, width: 260, height: 260)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(l10n.robotQrHint, textAlign: TextAlign.center, style: caption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

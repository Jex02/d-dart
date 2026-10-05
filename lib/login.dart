import 'package:flutter/material.dart';
import 'signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _panelColor = Color(0xFF8F1F0D);
  static const _accentColor = Color(0xFFD4AF37);
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 700;
                    final panelHeight = compact ? 330.0 : 346.0;
                    return Stack(
                      children: [
                        Positioned.fill(child: Image.asset('assets/lrac.jpg', fit: BoxFit.cover)),
                        Positioned.fill(child: ColoredBox(color: Colors.white.withOpacity(0.62))),
                        Positioned(
                          top: 0, left: 0, right: 0, bottom: panelHeight,
                          child: const _Branding(),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: _LoginPanel(
                            compact: compact,
                            rememberMe: _rememberMe,
                            obscurePassword: _obscurePassword,
                            onRememberChanged: (value) => setState(() => _rememberMe = value),
                            onPasswordVisibilityChanged: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Branding extends StatelessWidget {
  const _Branding();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 46, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('D-DART', style: TextStyle(color: Colors.black87, fontSize: 42, fontWeight: FontWeight.w500, letterSpacing: 3)),
            const SizedBox(height: 8),
            const Text(
              'Peer-to-Peer Campus Delivery Application', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8),
            ),
            const SizedBox(height: 21),
            RichText(
              text: const TextSpan(style: TextStyle(fontSize: 19, letterSpacing: 3), children: [
                TextSpan(text: 'Order.', style: TextStyle(color: Colors.black)),
                TextSpan(text: 'Run.', style: TextStyle(color: Color(0xFFD4AF37))),
                TextSpan(text: 'Deliver.', style: TextStyle(color: Color(0xFF8F1F0D))),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPanel extends StatelessWidget {
  const _LoginPanel({
    required this.compact, required this.rememberMe, required this.obscurePassword,
    required this.onRememberChanged, required this.onPasswordVisibilityChanged,
  });

  final bool compact;
  final bool rememberMe;
  final bool obscurePassword;
  final ValueChanged<bool> onRememberChanged;
  final VoidCallback onPasswordVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final fieldGap = compact ? 10.0 : 13.0;
    return Container(
      height: compact ? 330 : 346,
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(34, compact ? 26 : 32, 34, 18),
      decoration: const BoxDecoration(
        color: _LoginPageState._panelColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, -2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Welcome !', style: TextStyle(color: Colors.white, fontSize: 30)),
          SizedBox(height: compact ? 19 : 25),
          const _LoginTextField(hintText: 'Email', keyboardType: TextInputType.emailAddress),
          SizedBox(height: fieldGap),
          _LoginTextField(
            hintText: 'Password', obscureText: obscurePassword,
            suffix: IconButton(
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: onPasswordVisibilityChanged,
              icon: Icon(obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.black45, size: 20),
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          Row(children: [
            SizedBox(
              width: 25, height: 25,
              child: Checkbox(
                value: rememberMe, shape: const CircleBorder(), activeColor: Colors.white,
                checkColor: _LoginPageState._panelColor,
                side: const BorderSide(color: Colors.white, width: 1.5),
                onChanged: (value) => onRememberChanged(value ?? false),
              ),
            ),
            const SizedBox(width: 5),
            const Text('Remember', style: TextStyle(color: Colors.white, fontSize: 10)),
            const Spacer(),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero, minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Forgot Password?', style: TextStyle(fontSize: 10)),
            ),
          ]),
          SizedBox(height: compact ? 4 : 8),
          Center(
            child: SizedBox(
              width: 105, height: 30,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(backgroundColor: _LoginPageState._accentColor, foregroundColor: Colors.black, elevation: 0, padding: EdgeInsets.zero, shape: const StadiumBorder()),
                child: const Text('Login', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
          const Spacer(),
          const Divider(color: Colors.white54, height: 1),
          const SizedBox(height: 16),
          Center(
            child: Semantics(
              button: true,
              label: 'Sign up',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(
                    context,
                    rootNavigator: true,
                  ).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const SignupPage(),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  splashColor: Colors.white24,
                  highlightColor: Colors.white12,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          "Don't have account yet ?  ",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({required this.hintText, this.keyboardType, this.obscureText = false, this.suffix});
  final String hintText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 39,
      child: TextField(
        keyboardType: keyboardType, obscureText: obscureText, style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: hintText, hintStyle: const TextStyle(color: Colors.black87, fontSize: 12),
          filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 14), suffixIcon: suffix,
          border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15)), borderSide: BorderSide.none),
          enabledBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15)), borderSide: BorderSide.none),
          focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(15)), borderSide: BorderSide(color: _LoginPageState._accentColor, width: 2)),
        ),
      ),
    );
  }
}

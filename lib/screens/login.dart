import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'auth_wrapper.dart';
import 'cadastro.dart';
import '../tema/app_cores.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  final String? mensagemInicial;

  const LoginPage({super.key, this.mensagemInicial});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool loadingLogin = false;
  bool loadingGoogle = false;
  bool obscurePassword = true;

  @override
  void initState() {
    super.initState();

    if (widget.mensagemInicial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mensagemInicial!),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppCores.preto),
      prefixIcon: Icon(icon, color: AppCores.dourado),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppCores.branco,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppCores.preto.withOpacity(0.15)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppCores.dourado, width: 1.4),
      ),
    );
  }

  Future<void> loginComGoogle() async {
    if (loadingGoogle || loadingLogin) return;

    setState(() => loadingGoogle = true);

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();

        provider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final googleSignIn = GoogleSignIn();

        final googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          setState(() => loadingGoogle = false);
          return;
        }

        final googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
      }

      final user = userCredential.user;

      if (user == null) {
        if (mounted) {
          setState(() => loadingGoogle = false);
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();

        try {
          await GoogleSignIn().signOut();
        } catch (_) {}

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conta não cadastrada. Faça o cadastro primeiro.'),
            backgroundColor: Colors.red,
          ),
        );

        return;
      } else {
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(user.uid)
            .set({
              'nome': doc.data()?['nome'] ?? user.displayName ?? 'Cliente',
              'email': (user.email ?? '').toLowerCase(),
              'atualizadoEm': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao entrar com Google: ${e.message ?? e.code}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao entrar com Google: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loadingGoogle = false);
      }
    }
  }

  Future<void> login() async {
    if (loadingLogin || loadingGoogle) return;

    final email = emailController.text.trim().toLowerCase();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha email e senha'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => loadingLogin = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: senha,
      );

      final user = cred.user;

      if (user == null) throw Exception();

      await user.reload();
      final userAtualizado = FirebaseAuth.instance.currentUser;

      if (userAtualizado == null) throw Exception();
      final usuarioDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userAtualizado.uid)
          .get();

      if (!usuarioDoc.exists) {
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Usuário não encontrado. Faça o cadastro.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final tipoUsuario =
          usuarioDoc.data()?['tipo']?.toString().toLowerCase() ?? 'cliente';
      final isAdmin = tipoUsuario == 'admin';

      // 🔥 VERIFICA EMAIL AQUI (DEPOIS DO LOGIN)
      // 🔥 Cliente precisa verificar email. Admin entra sem verificar.
      if (!isAdmin && !userAtualizado.emailVerified) {
        try {
          await userAtualizado.sendEmailVerification();
        } catch (_) {}

        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Verifique seu email antes de entrar.\n\n'
              'Enviamos um novo email. Confira também Spam.',
            ),
            backgroundColor: Colors.orange,
          ),
        );

        return;
      }

      // continua fluxo normal...
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      String mensagem =
          'Sem conexão com a internet. Conecte-se para entrar no aplicativo.';

      if (e.code == 'user-not-found') {
        mensagem = 'Email não cadastrado. Faça o cadastro.';
      } else if (e.code == 'wrong-password') {
        mensagem = 'Senha incorreta';
      } else if (e.code == 'invalid-credential') {
        mensagem =
            'Email ou senha inválidos. Verifique os dados ou faça o cadastro.';
      } else if (e.code == 'invalid-email') {
        mensagem = 'Email inválido';
      } else if (e.code == 'too-many-requests') {
        mensagem = 'Muitas tentativas. Tente novamente mais tarde';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível entrar. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => loadingLogin = false);
      }
    }
  }

  Future<void> recuperarSenha() async {
    final email = emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite seu email para recuperar a senha.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se este email estiver cadastrado, enviaremos um link de recuperação de senha.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem =
          'Não foi possível enviar o email de recuperação. Tente novamente.';

      if (e.code == 'invalid-email') {
        mensagem = 'Email inválido.';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FB), Color(0xFFEAF0FF), AppCores.branco],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppCores.preto.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppCores.preto.withOpacity(0.10)),
                  ),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 130,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Prime Agenda',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppCores.preto,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !loadingLogin && !loadingGoogle,
                        style: const TextStyle(color: AppCores.preto),
                        decoration: _inputDecoration(
                          label: 'Email',
                          icon: Icons.email,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: senhaController,
                        obscureText: obscurePassword,
                        obscuringCharacter: '•',
                        enableSuggestions: false,
                        autocorrect: false,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !loadingLogin && !loadingGoogle,
                        onSubmitted: (_) => login(),
                        style: const TextStyle(color: AppCores.preto),
                        decoration: _inputDecoration(
                          label: 'Senha',
                          icon: Icons.lock,
                          suffixIcon: IconButton(
                            onPressed: loadingLogin || loadingGoogle
                                ? null
                                : () {
                                    setState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppCores.preto,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: loadingLogin || loadingGoogle
                              ? null
                              : recuperarSenha,
                          child: const Text(
                            'Esqueci minha senha',
                            style: TextStyle(color: AppCores.dourado),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: loadingLogin || loadingGoogle
                              ? null
                              : login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppCores.preto,
                            foregroundColor: AppCores.dourado,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: loadingLogin
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: AppCores.preto,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'Entrar',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text("ou"),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),

                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: loadingLogin || loadingGoogle
                              ? null
                              : loginComGoogle,
                          icon: loadingGoogle
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_rounded),
                          label: const Text('Entrar com Google'),
                        ),
                      ),

                      const SizedBox(height: 18),

                      TextButton(
                        onPressed: loadingLogin || loadingGoogle
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CadastroPage(),
                                  ),
                                );
                              },
                        child: const Text('Não possui uma conta? Criar conta'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

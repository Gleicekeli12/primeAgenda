import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'login.dart';
import 'agendamentos_admin.dart';
import 'cadastrar_profissional.dart';
import 'configuracao_funcionamento.dart';
import 'gerenciar_planos.dart';
import 'gerenciar_servicos.dart';
import 'gerenciar_categorias.dart';
import 'relatorio_faturamento.dart';
import 'assinaturas_planos_admin.dart';
import '../widgets/sininho_notificacoes.dart';
import '../tema/app_cores.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _adminStream;
  late Stream<DocumentSnapshot<Map<String, dynamic>>> _appConfigStream;
  bool _erroNaImagem = false;

  Stream<DocumentSnapshot<Map<String, dynamic>>> getDadosAdmin(String uid) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .snapshots();
  }

  Future<void> logout(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Sair',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja realmente sair?',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromRGBO(176, 125, 6, 1),
            ),
            child: const Text(
              'Cancelar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Sair',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();

      if (!context.mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  String pegarInicial(String nome) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return 'A';
    return nomeLimpo[0].toUpperCase();
  }

  Widget avatar(String nome, String fotoPerfil) {
    final usarImagem = fotoPerfil.trim().isNotEmpty && !_erroNaImagem;

    return CircleAvatar(
      radius: 45,
      backgroundColor: AppCores.dourado,
      backgroundImage: usarImagem
          ? CachedNetworkImageProvider(fotoPerfil.trim())
          : null,
      onBackgroundImageError: usarImagem
          ? (_, __) {
              if (mounted) {
                setState(() {
                  _erroNaImagem = true;
                });
              }
            }
          : null,
      child: !usarImagem
          ? const Icon(
              Icons.business_center_rounded,
              size: 42,
              color: AppCores.preto,
            )
          : null,
    );
  }

  Future<void> editarPerfilAdmin({
    required BuildContext context,
    required String uid,
    required String nomeAtual,
    required String fotoAtual,
  }) async {
    final nomeController = TextEditingController(text: nomeAtual);
    final subtituloController = TextEditingController();
    final sloganController = TextEditingController();
    XFile? imagemSelecionada;
    String? fotoPreview = fotoAtual;
    bool salvando = false;

    final appDoc = await FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('app')
        .get();

    final appData = appDoc.data() ?? {};

    subtituloController.text = appData['subtituloEmpresa']?.toString() ?? '';

    sloganController.text = appData['sloganEmpresa']?.toString() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> escolherImagem() async {
              final picker = ImagePicker();

              final picked = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 75,
                maxWidth: 900,
              );

              if (picked == null) return;

              setModalState(() {
                imagemSelecionada = picked;
                fotoPreview = null;
              });
            }

            Future<void> salvar() async {
              final nome = nomeController.text.trim();
              final subtitulo = subtituloController.text.trim();
              final slogan = sloganController.text.trim();

              if (nome.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Digite o nome do administrador'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => salvando = true);

              try {
                String fotoUrl = fotoPreview ?? '';

                if (imagemSelecionada != null) {
                  final ref = FirebaseStorage.instance
                      .ref()
                      .child('usuarios')
                      .child(uid)
                      .child('foto_perfil_admin.jpg');

                  if (kIsWeb) {
                    final bytes = await imagemSelecionada!.readAsBytes();

                    await ref.putData(
                      bytes,
                      SettableMetadata(contentType: 'image/jpeg'),
                    );
                  } else {
                    await ref.putFile(
                      File(imagemSelecionada!.path),
                      SettableMetadata(contentType: 'image/jpeg'),
                    );
                  }

                  fotoUrl = await ref.getDownloadURL();
                }

                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({
                      'nome': nome,
                      'nomeBusca': nome.toLowerCase(),
                      'fotoPerfil': fotoUrl,
                      'atualizadoEm': Timestamp.now(),
                    });
                await FirebaseFirestore.instance
                    .collection('configuracoes')
                    .doc('app')
                    .set({
                      'logoUrl': fotoUrl,
                      'nomeEmpresa': nome,
                      'subtituloEmpresa': subtitulo.isNotEmpty ? subtitulo : '',
                      'sloganEmpresa': slogan.isNotEmpty ? slogan : '',
                      'atualizadoEm': Timestamp.now(),
                    }, SetOptions(merge: true));

                if (!mounted) return;

                setState(() {
                  _erroNaImagem = false;
                });

                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perfil atualizado com sucesso'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                setModalState(() => salvando = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro ao atualizar perfil: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: AppCores.branco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Editar perfil',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppCores.preto),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: AppCores.dourado,
                          backgroundImage: imagemSelecionada != null && !kIsWeb
                              ? FileImage(File(imagemSelecionada!.path))
                              : fotoPreview != null && fotoPreview!.isNotEmpty
                              ? CachedNetworkImageProvider(fotoPreview!)
                              : null,
                          child:
                              imagemSelecionada == null &&
                                  (fotoPreview == null || fotoPreview!.isEmpty)
                              ? const Icon(
                                  Icons.business_center_rounded,
                                  size: 42,
                                  color: AppCores.preto,
                                )
                              : null,
                        ),

                        // BOTÃO DE REMOVER
                        if ((imagemSelecionada != null) ||
                            (fotoPreview != null && fotoPreview!.isNotEmpty))
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: salvando
                                  ? null
                                  : () {
                                      setModalState(() {
                                        imagemSelecionada = null;
                                        fotoPreview = '';
                                      });
                                    },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: AppCores.preto,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),

                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: salvando ? null : escolherImagem,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppCores.dourado,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: AppCores.preto,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nomeController,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.person,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppCores.dourado),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextField(
                      controller: subtituloController,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Subtítulo',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.title,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    TextField(
                      controller: sloganController,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.branco),
                      decoration: InputDecoration(
                        labelText: 'Slogan',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.format_quote,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppCores.preto),
                  ),
                ),
                ElevatedButton(
                  onPressed: salvando ? null : salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCores.preto,
                    foregroundColor: AppCores.dourado,
                  ),
                  child: salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppCores.preto,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Salvar',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nomeController.dispose();
  }

  Future<void> alterarEmailAdmin(BuildContext context) async {
    final novoEmailController = TextEditingController();
    final confirmarEmailController = TextEditingController();
    final senhaController = TextEditingController();

    bool salvando = false;
    bool ocultarSenha = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> salvarEmail() async {
              final novoEmail = novoEmailController.text.trim().toLowerCase();
              final confirmarEmail = confirmarEmailController.text
                  .trim()
                  .toLowerCase();
              final senha = senhaController.text.trim();

              if (novoEmail.isEmpty ||
                  confirmarEmail.isEmpty ||
                  senha.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha todos os campos'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (novoEmail != confirmarEmail) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Os e-mails não conferem'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(novoEmail)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Digite um e-mail válido'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => salvando = true);

              try {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null || user.email == null) {
                  throw Exception('Usuário não autenticado');
                }

                final uid = user.uid;
                final emailAtual = user.email!;

                final credential = EmailAuthProvider.credential(
                  email: emailAtual,
                  password: senha,
                );

                await user.reauthenticateWithCredential(credential);

                await user.verifyBeforeUpdateEmail(novoEmail);

                await FirebaseFirestore.instance
                    .collection('usuarios')
                    .doc(uid)
                    .update({
                      'emailPendente': novoEmail,
                      'emailAtual': emailAtual,
                      'atualizadoEm': Timestamp.now(),
                    });

                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Enviamos um link para $novoEmail. Confirme o novo e-mail para concluir a alteração.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                String mensagem = 'Erro ao alterar e-mail';

                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  mensagem = 'Senha atual incorreta';
                } else if (e.code == 'email-already-in-use') {
                  mensagem = 'Este e-mail já está sendo usado por outra conta';
                } else if (e.code == 'invalid-email') {
                  mensagem = 'E-mail inválido';
                } else if (e.code == 'requires-recent-login') {
                  mensagem = 'Faça login novamente para alterar o e-mail';
                }

                if (!context.mounted) return;
                setModalState(() => salvando = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mensagem),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                setModalState(() => salvando = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              backgroundColor: AppCores.branco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Alterar e-mail',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppCores.preto),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: novoEmailController,
                      enabled: !salvando,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Novo e-mail',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.email,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmarEmailController,
                      enabled: !salvando,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Confirmar novo e-mail',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.mark_email_read,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: senhaController,
                      enabled: !salvando,
                      obscureText: ocultarSenha,
                      obscuringCharacter: '•',
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Senha atual',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: AppCores.dourado,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            ocultarSenha
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: salvando
                              ? null
                              : () {
                                  setModalState(
                                    () => ocultarSenha = !ocultarSenha,
                                  );
                                },
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppCores.preto),
                  ),
                ),
                ElevatedButton(
                  onPressed: salvando ? null : salvarEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCores.preto,
                    foregroundColor: AppCores.dourado,
                  ),
                  child: salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppCores.preto,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Enviar verificação',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    novoEmailController.dispose();
    confirmarEmailController.dispose();
    senhaController.dispose();
  }

  Future<void> alterarSenhaAdmin(BuildContext context) async {
    final senhaAtualController = TextEditingController();
    final novaSenhaController = TextEditingController();
    final confirmarSenhaController = TextEditingController();

    bool salvando = false;
    bool ocultarAtual = true;
    bool ocultarNova = true;
    bool ocultarConfirmar = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> salvarSenha() async {
              final senhaAtual = senhaAtualController.text.trim();
              final novaSenha = novaSenhaController.text.trim();
              final confirmarSenha = confirmarSenhaController.text.trim();

              if (senhaAtual.isEmpty ||
                  novaSenha.isEmpty ||
                  confirmarSenha.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha todos os campos'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (novaSenha.length < 8 ||
                  !RegExp(r'[A-Z]').hasMatch(novaSenha) ||
                  !RegExp(r'[a-z]').hasMatch(novaSenha) ||
                  !RegExp(r'[^\w\s]').hasMatch(novaSenha)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'A nova senha deve ter no mínimo 8 caracteres, letra maiúscula, minúscula e símbolo',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (novaSenha != confirmarSenha) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('As senhas não conferem'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => salvando = true);

              try {
                final user = FirebaseAuth.instance.currentUser;

                if (user == null || user.email == null) {
                  throw Exception('Usuário não autenticado');
                }

                final credential = EmailAuthProvider.credential(
                  email: user.email!,
                  password: senhaAtual,
                );

                await user.reauthenticateWithCredential(credential);
                await user.updatePassword(novaSenha);

                if (!context.mounted) return;
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Senha alterada com sucesso'),
                    backgroundColor: Colors.green,
                  ),
                );
              } on FirebaseAuthException catch (e) {
                String mensagem = 'Erro ao alterar senha';

                if (e.code == 'wrong-password' ||
                    e.code == 'invalid-credential') {
                  mensagem = 'Senha atual incorreta';
                } else if (e.code == 'weak-password') {
                  mensagem = 'A nova senha é muito fraca';
                } else if (e.code == 'requires-recent-login') {
                  mensagem = 'Faça login novamente para alterar a senha';
                }

                if (!context.mounted) return;

                setModalState(() => salvando = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(mensagem),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                setModalState(() => salvando = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erro: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            InputDecoration decoracaoSenha({
              required String label,
              required IconData icon,
              required bool ocultar,
              required VoidCallback onToggle,
            }) {
              return InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: Colors.grey.shade700),
                prefixIcon: Icon(icon, color: AppCores.dourado),
                suffixIcon: IconButton(
                  icon: Icon(
                    ocultar ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: salvando ? null : onToggle,
                ),
                filled: true,
                fillColor: AppCores.fundoClaro,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppCores.dourado),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppCores.branco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Alterar senha',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppCores.preto),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: senhaAtualController,
                      obscureText: ocultarAtual,
                      obscuringCharacter: '•',
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: decoracaoSenha(
                        label: 'Senha atual',
                        icon: Icons.lock_outline,
                        ocultar: ocultarAtual,
                        onToggle: () {
                          setModalState(() => ocultarAtual = !ocultarAtual);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: novaSenhaController,
                      obscureText: ocultarNova,
                      obscuringCharacter: '•',
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: decoracaoSenha(
                        label: 'Nova senha',
                        icon: Icons.lock_reset,
                        ocultar: ocultarNova,
                        onToggle: () {
                          setModalState(() => ocultarNova = !ocultarNova);
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmarSenhaController,
                      obscureText: ocultarConfirmar,
                      obscuringCharacter: '•',
                      enableSuggestions: false,
                      autocorrect: false,
                      keyboardType: TextInputType.visiblePassword,
                      enabled: !salvando,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: decoracaoSenha(
                        label: 'Confirmar nova senha',
                        icon: Icons.check_circle_outline,
                        ocultar: ocultarConfirmar,
                        onToggle: () {
                          setModalState(
                            () => ocultarConfirmar = !ocultarConfirmar,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: salvando ? null : () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppCores.preto),
                  ),
                ),
                ElevatedButton(
                  onPressed: salvando ? null : salvarSenha,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCores.preto,
                    foregroundColor: AppCores.dourado,
                  ),
                  child: salvando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: AppCores.preto,
                            strokeWidth: 2.4,
                          ),
                        )
                      : const Text(
                          'Salvar senha',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    senhaAtualController.dispose();
    novaSenhaController.dispose();
    confirmarSenhaController.dispose();
  }

  Widget botaoAdmin({
    required BuildContext context,
    required String titulo,
    required String subtitulo,
    required IconData icone,
    required Widget pagina,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppCores.preto,
          border: Border.all(color: AppCores.preto.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Color.fromRGBO(234, 219, 195, 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icone, color: AppCores.dourado),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppCores.branco,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    _adminStream = user != null
        ? getDadosAdmin(user.uid)
        : const Stream.empty();

    _appConfigStream = FirebaseFirestore.instance
        .collection('configuracoes')
        .doc('app')
        .snapshots();
  }

  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppCores.preto,
        body: Center(child: CircularProgressIndicator(color: AppCores.dourado)),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Painel Administrativo'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          const SininhoNotificacoes(userId: 'admin', admin: true),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => logout(context),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F7FB), Color(0xFFEDEEF2), AppCores.branco],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _appConfigStream,
          builder: (context, appSnapshot) {
            final appDados = appSnapshot.data?.data() ?? {};

            final modoAssinaturas = appDados['modoAssinaturas'] == true;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _adminStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppCores.dourado),
                  );
                }

                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar dados',
                      style: TextStyle(color: AppCores.branco),
                    ),
                  );
                }

                final doc = snapshot.data;

                if (doc == null || !doc.exists || doc.data() == null) {
                  return const Center(
                    child: Text(
                      'Dados do administrador não encontrados',
                      style: TextStyle(color: AppCores.branco),
                    ),
                  );
                }

                final dados = doc.data()!;

                final tipo = dados['tipo']?.toString() ?? '';

                if (tipo != 'admin') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                    );
                  });

                  return const Center(
                    child: Text(
                      'Acesso negado',
                      style: TextStyle(color: AppCores.branco),
                    ),
                  );
                }

                final nome = dados['nome']?.toString().trim().isNotEmpty == true
                    ? dados['nome'].toString().trim()
                    : 'Administrador';

                final fotoPerfil = dados['fotoPerfil']?.toString() ?? '';

                return SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            color: const Color.fromRGBO(255, 255, 255, 0.05),
                            border: Border.all(
                              color: AppCores.branco.withOpacity(0.06),
                            ),
                          ),
                          child: Column(
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 150,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Prime Agenda',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppCores.preto,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Sistema de agendamentos',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => editarPerfilAdmin(
                                  context: context,
                                  uid: user.uid,
                                  nomeAtual: nome,
                                  fotoAtual: fotoPerfil,
                                ),
                                icon: const Icon(Icons.edit),
                                label: const Text('Editar perfil'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color.fromRGBO(
                                    176,
                                    125,
                                    6,
                                    1,
                                  ),
                                  side: BorderSide(
                                    color: Color.fromRGBO(176, 125, 6, 0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => alterarEmailAdmin(context),
                                icon: const Icon(Icons.alternate_email),
                                label: const Text('Alterar e-mail'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color.fromRGBO(
                                    176,
                                    125,
                                    6,
                                    1,
                                  ),
                                  side: BorderSide(
                                    color: Color.fromRGBO(176, 125, 6, 0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => alterarSenhaAdmin(context),
                                icon: const Icon(Icons.lock_reset),
                                label: const Text('Alterar senha'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Color.fromRGBO(
                                    176,
                                    125,
                                    6,
                                    1,
                                  ),
                                  side: BorderSide(
                                    color: Color.fromRGBO(176, 125, 6, 0.45),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 30, bottom: 1),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(176, 125, 6, 0.14),
                                AppCores.branco.withOpacity(0.04),
                              ],
                            ),
                            border: Border.all(
                              color: Color.fromRGBO(176, 125, 6, 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(176, 125, 6, 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.insights_rounded,
                                  color: AppCores.dourado,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Acompanhamento',
                                      style: TextStyle(
                                        color: AppCores.preto,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Monitoramento da operação e receitas',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Agendamentos',
                          subtitulo: 'Ver e gerenciar',
                          icone: Icons.calendar_month,
                          pagina: const AgendamentosAdminPage(),
                        ),
                        if (modoAssinaturas) ...[
                          const SizedBox(height: 12),
                          botaoAdmin(
                            context: context,
                            titulo: 'Assinaturas de Planos',
                            subtitulo: 'Ver assinantes',
                            icone: Icons.subscriptions,
                            pagina: const AssinaturasPlanosAdminPage(),
                          ),
                        ],

                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Faturamento',
                          subtitulo: 'Resumo mensal e por profissional',
                          icone: Icons.bar_chart_rounded,
                          pagina: const RelatorioFaturamentoPage(),
                        ),
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 50, bottom: 1),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Color.fromRGBO(
                                  176,
                                  125,
                                  6,
                                  1,
                                ).withOpacity(0.14),
                                AppCores.branco.withOpacity(0.04),
                              ],
                            ),
                            border: Border.all(
                              color: Color.fromRGBO(
                                176,
                                125,
                                6,
                                1,
                              ).withOpacity(0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: Color.fromRGBO(
                                    176,
                                    125,
                                    6,
                                    1,
                                  ).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.tune_rounded,
                                  color: AppCores.dourado,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Gestão da empresa',
                                      style: TextStyle(
                                        color: AppCores.preto,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Configurações e estrutura da empresa',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Cadastrar Profissional',
                          subtitulo: 'Adicionar novos profissionais',
                          icone: Icons.person_add,
                          pagina: const CadastrarProfissionalPage(),
                        ),

                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Gerenciar Categorias',
                          subtitulo: 'Criar e organizar categorias',
                          icone: Icons.category_outlined,
                          pagina: const GerenciarCategoriasPage(),
                        ),

                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Gerenciar Serviços',
                          subtitulo: 'Editar serviços',
                          icone: Icons.design_services_rounded,
                          pagina: const GerenciarServicosPage(),
                        ),

                        if (modoAssinaturas) ...[
                          const SizedBox(height: 12),
                          botaoAdmin(
                            context: context,
                            titulo: 'Gerenciar Planos',
                            subtitulo: 'Planos de assinatura e benefícios',
                            icone: Icons.workspace_premium,
                            pagina: const GerenciarPlanosPage(),
                          ),
                        ],
                        const SizedBox(height: 12),
                        botaoAdmin(
                          context: context,
                          titulo: 'Funcionamento',
                          subtitulo: 'Horários e regras',
                          icone: Icons.schedule,
                          pagina: const ConfiguracaoFuncionamentoPage(),
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
    );
  }
}

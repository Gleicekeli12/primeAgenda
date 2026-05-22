import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../tema/app_cores.dart';

class CadastrarProfissionalPage extends StatefulWidget {
  const CadastrarProfissionalPage({super.key});

  @override
  State<CadastrarProfissionalPage> createState() =>
      _CadastrarProfissionalPageState();
}

class _CadastrarProfissionalPageState extends State<CadastrarProfissionalPage> {
  final nomeFocus = FocusNode();
  final especialidadeFocus = FocusNode();
  final nomeController = TextEditingController();
  final especialidadeController = TextEditingController();
  XFile? imagemSelecionada;

  bool carregando = false;

  Future<void> adicionarProfissional() async {
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final especialidade = especialidadeController.text.trim();

    if (nome.isEmpty || especialidade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final existente = await FirebaseFirestore.instance
          .collection('profissionais')
          .where('nomeBusca', isEqualTo: nome.toLowerCase())
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty) {
        throw Exception('Já existe um profissional com esse nome');
      }
      String fotoUrl = '';

      if (imagemSelecionada != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profissionais')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        if (kIsWeb) {
          final bytes = await imagemSelecionada!.readAsBytes();

          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putFile(
            File(imagemSelecionada!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }

        fotoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('profissionais').add({
        'nome': nome,
        'nomeBusca': nome.toLowerCase(),
        'especialidade': especialidade,
        'fotoUrl': fotoUrl,
        'criadoEm': Timestamp.now(),
      });

      nomeController.clear();
      especialidadeController.clear();

      nomeFocus.unfocus();
      especialidadeFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        imagemSelecionada = null;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profissional cadastrado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao salvar profissional';

      if (e.toString().contains('Já existe um profissional com esse nome')) {
        mensagem = 'Já existe um profissional com esse nome';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> escolherImagem() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 900,
    );

    if (picked == null) return;

    setState(() {
      imagemSelecionada = picked;
    });
  }

  Future<void> removerProfissional(String id) async {
    try {
      final profissionalDoc = await FirebaseFirestore.instance
          .collection('profissionais')
          .doc(id)
          .get();

      final nomeProfissional =
          profissionalDoc.data()?['nome']?.toString().trim() ?? '';

      if (nomeProfissional.isNotEmpty) {
        final agendamentos = await FirebaseFirestore.instance
            .collection('agendamentos')
            .where('profissionalId', isEqualTo: id)
            .where('status', isEqualTo: 'agendado')
            .limit(1)
            .get();

        if (agendamentos.docs.isNotEmpty) {
          throw Exception('Este profissional possui agendamentos ativos');
        }
      }
      final fotoUrl = profissionalDoc.data()?['fotoUrl'] ?? '';

      if (fotoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(fotoUrl).delete();
        } catch (_) {}
      }

      await FirebaseFirestore.instance
          .collection('profissionais')
          .doc(id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profissional removido com sucesso'),
          backgroundColor: Colors.green,
        ),
      );

      FocusManager.instance.primaryFocus?.unfocus();
      nomeFocus.unfocus();
      especialidadeFocus.unfocus();
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao remover profissional';

      if (e.toString().contains(
        'Este profissional possui agendamentos ativos',
      )) {
        mensagem =
            'Não é possível remover um profissional com agendamentos ativos';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );

      FocusManager.instance.primaryFocus?.unfocus();
      nomeFocus.unfocus();
      especialidadeFocus.unfocus();
    }
  }

  String pegarInicial(String nome) {
    final nomeLimpo = nome.trim();
    if (nomeLimpo.isEmpty) return 'P';
    return nomeLimpo[0].toUpperCase();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      floatingLabelStyle: const TextStyle(color: AppCores.dourado),
      prefixIcon: Icon(icon, color: AppCores.dourado),
      filled: true,
      fillColor: AppCores.fundoClaro,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppCores.dourado, width: 1.4),
      ),
    );
  }

  InputDecoration _inputDecorationDialog({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      floatingLabelStyle: const TextStyle(color: AppCores.dourado),
      prefixIcon: Icon(icon, color: AppCores.dourado),
      filled: true,
      fillColor: AppCores.fundoClaro,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppCores.dourado, width: 1.4),
      ),
    );
  }

  Future<void> confirmarRemocao(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppCores.branco,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Excluir profissional',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppCores.preto,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Deseja realmente excluir "$nome"?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppCores.preto),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: AppCores.branco,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Excluir',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      await removerProfissional(id);
    }
  }

  Future<void> editarProfissional(String id, Map<String, dynamic> dados) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final nomeCtrl = TextEditingController(
      text: dados['nome']?.toString() ?? '',
    );
    final especialidadeCtrl = TextEditingController(
      text: dados['especialidade']?.toString() ?? '',
    );
    XFile? novaImagem;
    String imagemAtual = dados['fotoUrl']?.toString() ?? '';
    bool removerImagem = false;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: AppCores.branco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: const Text(
                'Editar profissional',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppCores.preto,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 FOTO
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: AppCores.dourado,
                          backgroundImage: novaImagem != null && !kIsWeb
                              ? FileImage(File(novaImagem!.path))
                              : (!removerImagem && imagemAtual.isNotEmpty)
                              ? CachedNetworkImageProvider(imagemAtual)
                              : null,
                          child:
                              novaImagem == null &&
                                  (removerImagem || imagemAtual.isEmpty)
                              ? Text(
                                  pegarInicial(nomeCtrl.text),
                                  style: const TextStyle(
                                    color: AppCores.branco,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),

                        // ❌ remover imagem
                        if (novaImagem != null || imagemAtual.isNotEmpty)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () {
                                setStateModal(() {
                                  novaImagem = null;
                                  removerImagem = true;
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
                                  color: AppCores.branco,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),

                        // 📷 escolher imagem
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final picker = ImagePicker();
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                                imageQuality: 75,
                                maxWidth: 900,
                              );

                              if (picked == null) return;

                              setStateModal(() {
                                novaImagem = picked;
                                removerImagem = false;
                              });
                            },
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

                    const SizedBox(height: 16),

                    TextField(
                      controller: nomeCtrl,
                      style: const TextStyle(color: AppCores.preto),
                      cursorColor: AppCores.dourado,
                      decoration: _inputDecorationDialog(
                        label: 'Nome',
                        icon: Icons.person_outline,
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: especialidadeCtrl,
                      style: const TextStyle(color: AppCores.preto),
                      cursorColor: AppCores.dourado,
                      decoration: _inputDecorationDialog(
                        label: 'Especialidade',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppCores.preto),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppCores.dourado,
                    foregroundColor: AppCores.branco,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
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

    if (salvar != true) return;

    final nome = nomeCtrl.text.trim();
    final especialidade = especialidadeCtrl.text.trim();

    if (nome.isEmpty || especialidade.isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existente = await FirebaseFirestore.instance
        .collection('profissionais')
        .where('nomeBusca', isEqualTo: nome.toLowerCase())
        .limit(1)
        .get();

    final nomeJaExiste = existente.docs.any((doc) => doc.id != id);
    if (nomeJaExiste) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe um profissional com esse nome'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String fotoFinal = imagemAtual;

      if (removerImagem) {
        fotoFinal = '';
      }

      if (novaImagem != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('profissionais')
            .child('$id.jpg');

        if (kIsWeb) {
          final bytes = await novaImagem!.readAsBytes();

          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putFile(
            File(novaImagem!.path),
            SettableMetadata(contentType: 'image/jpeg'),
          );
        }
        fotoFinal = await ref.getDownloadURL();
      }
      await FirebaseFirestore.instance
          .collection('profissionais')
          .doc(id)
          .update({
            'nome': nome,
            'nomeBusca': nome.toLowerCase(),
            'especialidade': especialidade,
            'fotoUrl': fotoFinal,
            'atualizadoEm': Timestamp.now(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profissional atualizado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao atualizar profissional';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para editar profissional';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    nomeController.dispose();
    especialidadeController.dispose();
    nomeFocus.dispose();
    especialidadeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Cadastrar Profissional'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppCores.preto,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppCores.fundoClaro,
              AppCores.fundoClaro2,
              AppCores.branco,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
               color: AppCores.branco,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
blurRadius: 12,
offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        GestureDetector(
                          onTap: carregando ? null : escolherImagem,
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppCores.dourado,
                            backgroundImage:
                                imagemSelecionada != null && !kIsWeb
                                ? FileImage(File(imagemSelecionada!.path))
                                : null,
                            child: imagemSelecionada == null
                                ? const Icon(
                                    Icons.camera_alt,
                                    color: AppCores.preto,
                                    size: 28,
                                  )
                                : null,
                          ),
                        ),
                        if (imagemSelecionada != null)
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: carregando
                                  ? null
                                  : () {
                                      setState(() {
                                        imagemSelecionada = null;
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
                                  color: AppCores.branco,
                                  size: 17,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      imagemSelecionada == null
                          ? 'Adicionar foto opcional'
                          : 'Foto selecionada',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      style: const TextStyle(color: AppCores.preto),
                      cursorColor: AppCores.dourado,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        label: 'Nome do profissional',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: especialidadeController,
                      focusNode: especialidadeFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      style: const TextStyle(color: AppCores.preto),
                      cursorColor: AppCores.dourado,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!carregando) {
                          adicionarProfissional();
                        }
                      },
                      decoration: _inputDecoration(
                        label: 'Especialidade',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarProfissional,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppCores.dourado,
                          foregroundColor: AppCores.preto,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: carregando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppCores.preto,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Adicionar Profissional',
                                style: TextStyle(
                                  color: AppCores.branco,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('profissionais')
                    .orderBy('nomeBusca')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar profissionais',
                      style: TextStyle(color: AppCores.preto),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppCores.dourado),
                    );
                  }

                  final profissionais = snapshot.data?.docs ?? [];

                  if (profissionais.isEmpty) {
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                         color: AppCores.branco,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                           color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.people_alt_rounded,
                              size: 42,
                              color: AppCores.dourado.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum profissional cadastrado',
                              style: TextStyle(
                                color: AppCores.preto,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cadastre profissionais para iniciar os atendimentos.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: profissionais.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = profissionais[index];
                      final profissional = doc.data();

                      final nome = profissional['nome']?.toString() ?? '';
                      final especialidade =
                          profissional['especialidade']?.toString() ?? '';
                      final fotoUrl = profissional['fotoUrl']?.toString() ?? '';

                      return Container(
                        key: ValueKey(doc.id),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(
                            colors: [
  AppCores.branco,
  AppCores.branco,
],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                         color: Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
blurRadius: 8,
offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppCores.dourado,
                              backgroundImage: fotoUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(fotoUrl)
                                  : null,
                              child: fotoUrl.isEmpty
                                  ? Text(
                                      pegarInicial(nome),
                                      style: const TextStyle(
                                        color: AppCores.branco,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nome.isEmpty ? 'Sem nome' : nome,
                                    style: const TextStyle(
                                      color: AppCores.preto,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    especialidade.isEmpty
                                        ? 'Especialidade não informada'
                                        : 'Especialidade: $especialidade',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 18,
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: AppCores.dourado,
                                    ),
                                    onPressed: () async {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      await Future.delayed(
                                        const Duration(milliseconds: 200),
                                      );
                                      if (!context.mounted) return;
                                      await editarProfissional(
                                        doc.id,
                                        profissional,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    iconSize: 18,
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () async {
                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                      await Future.delayed(
                                        const Duration(milliseconds: 200),
                                      );
                                      if (!context.mounted) return;
                                      await confirmarRemocao(doc.id, nome);

                                      FocusManager.instance.primaryFocus
                                          ?.unfocus();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

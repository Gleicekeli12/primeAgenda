import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import '../tema/app_cores.dart';

class GerenciarServicosPage extends StatefulWidget {
  const GerenciarServicosPage({super.key});

  @override
  State<GerenciarServicosPage> createState() => _GerenciarServicosPageState();
}

class _GerenciarServicosPageState extends State<GerenciarServicosPage> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _categoriasStream;

  final nomeFocus = FocusNode();
  final descricaoFocus = FocusNode();
  final precoFocus = FocusNode();

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final precoController = TextEditingController();
  XFile? imagemSelecionada;

  String? categoriaId;
  String? categoriaNome;

  bool carregando = false;

  @override
  void initState() {
    super.initState();

    _categoriasStream = FirebaseFirestore.instance
        .collection('categorias_servicos')
        .orderBy('ordem')
        .snapshots();
  }

  Future<void> adicionarServico() async {
    if (carregando) return;
    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final descricao = descricaoController.text.trim();
    final precoTexto = precoController.text.trim();

    if (nome.isEmpty ||
        descricao.isEmpty ||
        precoTexto.isEmpty ||
        categoriaId == null ||
        categoriaNome == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha tudo e selecione a categoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final precoNormalizado = precoTexto
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final preco = double.tryParse(precoNormalizado);

    if (preco == null || preco <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite um preço válido'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final existente = await FirebaseFirestore.instance
          .collection('servicos')
          .where('categoriaId', isEqualTo: categoriaId)
          .where('nomeBusca', isEqualTo: nome.toLowerCase().trim())
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty) {
        throw Exception('Já existe um serviço com esse nome nesta categoria');
      }
      String imagemUrl = '';

      if (imagemSelecionada != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('servicos')
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

        imagemUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('servicos').add({
        'nome': nome,
        'nomeBusca': nome.toLowerCase().trim(),
        'descricao': descricao,
        'preco': preco,
        'categoriaId': categoriaId,
        'categoriaNome': categoriaNome,
        'imagemUrl': imagemUrl,
        'ativo': true,
        'criadoEm': FieldValue.serverTimestamp(),
      });

      nomeController.clear();
      descricaoController.clear();
      precoController.clear();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();

      FocusManager.instance.primaryFocus?.unfocus();

      if (mounted) {
        setState(() {
          categoriaId = null;
          categoriaNome = null;
          imagemSelecionada = null;
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço cadastrado com sucesso'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao salvar serviço';

      if (e.toString().contains(
        'Já existe um serviço com esse nome nesta categoria',
      )) {
        mensagem = 'Já existe um serviço com esse nome nesta categoria';
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

  Future<void> removerServico(String id, String nome) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppCores.branco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Excluir serviço',
          style: TextStyle(color: AppCores.preto, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Deseja realmente excluir "$nome"?',
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
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('servicos')
          .doc(id)
          .get();

      final imagemUrl = doc.data()?['imagemUrl'] ?? '';

      if (imagemUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(imagemUrl).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance.collection('servicos').doc(id).delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço removido com sucesso'),
          backgroundColor: Colors.green,
        ),
      );

      FocusManager.instance.primaryFocus?.unfocus();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover serviço'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> editarServico(String id, Map<String, dynamic> dados) async {
    FocusScope.of(context).unfocus();
    final nomeCtrl = TextEditingController(
      text: dados['nome']?.toString() ?? '',
    );

    final descricaoCtrl = TextEditingController(
      text: dados['descricao']?.toString() ?? '',
    );

    final precoCtrl = TextEditingController(
      text: formatarPreco(dados['preco']),
    );

    String? novaCategoriaId = dados['categoriaId']?.toString();
    String? novaCategoriaNome = dados['categoriaNome']?.toString();
    XFile? novaImagem;
    String imagemAtual = dados['imagemUrl']?.toString() ?? '';
    bool removerImagem = false;

    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: AppCores.branco,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Editar serviço',
                style: TextStyle(
                  color: AppCores.preto,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                              ? const Icon(
                                  Icons.design_services_rounded,
                                  color: AppCores.preto,
                                  size: 28,
                                )
                              : null,
                        ),

                        // botão remover
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

                        // botão escolher imagem
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
                    const SizedBox(height: 12),

                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () async {
                        final selecionada = await selecionarCategoriaServico(
                          categoriaAtualId: novaCategoriaId,
                        );

                        if (selecionada == null) return;

                        setStateModal(() {
                          novaCategoriaId = selecionada.id;
                          novaCategoriaNome =
                              selecionada.data()['nome']?.toString() ??
                              'Categoria';
                        });
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Categoria',
                          labelStyle: TextStyle(color: Colors.grey.shade700),
                          prefixIcon: const Icon(
                            Icons.category,
                            color: AppCores.dourado,
                          ),
                          suffixIcon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppCores.dourado,
                          ),
                          filled: true,
                          fillColor: AppCores.fundoClaro,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: Colors.black.withOpacity(0.06),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppCores.dourado,
                              width: 1.4,
                            ),
                          ),
                        ),
                        child: Text(
                          novaCategoriaNome?.isNotEmpty == true
                              ? novaCategoriaNome!
                              : 'Selecionar categoria',
                          style: const TextStyle(color: AppCores.preto),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: nomeCtrl,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Nome',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.design_services_rounded,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppCores.dourado,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descricaoCtrl,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.description,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppCores.dourado,
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(color: AppCores.preto),
                      decoration: InputDecoration(
                        labelText: 'Preço',
                        labelStyle: TextStyle(color: Colors.grey.shade700),
                        prefixIcon: const Icon(
                          Icons.attach_money,
                          color: AppCores.dourado,
                        ),
                        filled: true,
                        fillColor: AppCores.fundoClaro,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withOpacity(0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppCores.dourado,
                            width: 1.4,
                          ),
                        ),
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
                    foregroundColor: AppCores.preto,
                  ),
                  child: const Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppCores.branco,
                      fontWeight: FontWeight.bold,
                    ),
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
    final descricao = descricaoCtrl.text.trim();
    final precoTexto = precoCtrl.text.trim();

    final precoNormalizado = precoTexto
        .replaceAll('.', '')
        .replaceAll(',', '.');
    final preco = double.tryParse(precoNormalizado);

    if (nome.isEmpty ||
        descricao.isEmpty ||
        preco == null ||
        preco <= 0 ||
        novaCategoriaId == null ||
        novaCategoriaNome == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os dados corretamente'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existente = await FirebaseFirestore.instance
        .collection('servicos')
        .where('categoriaId', isEqualTo: novaCategoriaId)
        .where('nomeBusca', isEqualTo: nome.toLowerCase().trim())
        .limit(1)
        .get();

    final duplicado = existente.docs.any((doc) => doc.id != id);

    if (duplicado) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Já existe um serviço com esse nome nesta categoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      String imagemFinal = imagemAtual;

      if (removerImagem) {
        imagemFinal = '';
      }

      if (novaImagem != null) {
        final ref = FirebaseStorage.instance
            .ref()
            .child('servicos')
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
        imagemFinal = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('servicos').doc(id).update({
        'nome': nome,
        'nomeBusca': nome.toLowerCase().trim(),
        'descricao': descricao,
        'preco': preco,
        'categoriaId': novaCategoriaId,
        'categoriaNome': novaCategoriaNome,
        'imagemUrl': imagemFinal,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serviço atualizado'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String mensagem = 'Erro ao atualizar serviço';

      if (e.toString().contains('permission-denied')) {
        mensagem = 'Sem permissão para editar serviço';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    }
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  selecionarCategoriaServico({String? categoriaAtualId}) async {
    final snap = await FirebaseFirestore.instance
        .collection('categorias_servicos')
        .orderBy('ordem')
        .get();

    if (!mounted) return null;

    final categorias = snap.docs;

    if (categorias.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma categoria cadastrada'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return showModalBottomSheet<QueryDocumentSnapshot<Map<String, dynamic>>>(
      context: context,
      backgroundColor: AppCores.branco,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Selecionar categoria',
                  style: TextStyle(
                    color: AppCores.preto,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...categorias.map((doc) {
                  final nome = doc.data()['nome']?.toString() ?? 'Categoria';

                  return ListTile(
                    title: Text(
                      nome,
                      style: const TextStyle(color: AppCores.preto),
                    ),
                    trailing: doc.id == categoriaAtualId
                        ? const Icon(Icons.check, color: AppCores.dourado)
                        : null,
                    onTap: () => Navigator.pop(context, doc),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade700),
      prefixIcon: Icon(icon, color: AppCores.dourado),
      filled: true,
      fillColor: AppCores.fundoClaro,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppCores.dourado, width: 1.4),
      ),
    );
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }
    return '0,00';
  }

  IconData iconeServicoPorCategoria(String categoriaNome) {
    final n = categoriaNome.toLowerCase();

    if (n.contains('consulta')) {
      return Icons.medical_services_rounded;
    }

    if (n.contains('terapia')) {
      return Icons.psychology_rounded;
    }

    if (n.contains('estetica') || n.contains('estética')) {
      return Icons.spa_rounded;
    }

    if (n.contains('massagem')) {
      return Icons.self_improvement_rounded;
    }

    if (n.contains('tattoo') || n.contains('tatuagem')) {
      return Icons.draw_rounded;
    }

    if (n.contains('manicure') || n.contains('unha')) {
      return Icons.back_hand_rounded;
    }

    // PADRÃO
    return Icons.design_services_rounded;
  }

  @override
  void dispose() {
    nomeController.dispose();
    descricaoController.dispose();
    precoController.dispose();

    nomeFocus.dispose();
    descricaoFocus.dispose();
    precoFocus.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Gerenciar Serviços'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppCores.fundoClaro,
              AppCores.fundoClaro2,
              AppCores.branco,
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + keyboardHeight),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppCores.branco,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _categoriasStream,
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppCores.dourado,
                            ),
                          );
                        }

                        if (snap.hasError) {
                          return const Text(
                            'Erro ao carregar categorias',
                            style: TextStyle(color: AppCores.preto),
                          );
                        }

                        final categorias = snap.data?.docs ?? [];

                        categorias.sort((a, b) {
                          final ordemA = a.data()['ordem'];
                          final ordemB = b.data()['ordem'];

                          final valorA = ordemA is num ? ordemA : 9999;
                          final valorB = ordemB is num ? ordemB : 9999;

                          return valorA.compareTo(valorB);
                        });

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: categorias.isEmpty
                              ? null
                              : () async {
                                  FocusScope.of(context).unfocus();

                                  final selecionada =
                                      await showModalBottomSheet<
                                        QueryDocumentSnapshot<
                                          Map<String, dynamic>
                                        >
                                      >(
                                        context: context,
                                        backgroundColor: AppCores.branco,
                                        shape: const RoundedRectangleBorder(
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(24),
                                          ),
                                        ),
                                        builder: (_) {
                                          return SafeArea(
                                            child: ListView(
                                              padding: const EdgeInsets.all(16),
                                              children: [
                                                const Text(
                                                  'Selecione a categoria',
                                                  style: TextStyle(
                                                    color: AppCores.preto,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                ...categorias.map((doc) {
                                                  final nome =
                                                      doc
                                                          .data()['nome']
                                                          ?.toString() ??
                                                      'Categoria';

                                                  return ListTile(
                                                    title: Text(
                                                      nome,
                                                      style: const TextStyle(
                                                        color: AppCores.preto,
                                                      ),
                                                    ),
                                                    trailing:
                                                        doc.id == categoriaId
                                                        ? const Icon(
                                                            Icons.check,
                                                            color: AppCores
                                                                .dourado,
                                                          )
                                                        : null,
                                                    onTap: () => Navigator.pop(
                                                      context,
                                                      doc,
                                                    ),
                                                  );
                                                }),
                                              ],
                                            ),
                                          );
                                        },
                                      );

                                  if (selecionada == null) return;

                                  setState(() {
                                    categoriaId = selecionada.id;
                                    categoriaNome =
                                        selecionada
                                            .data()['nome']
                                            ?.toString() ??
                                        'Categoria';
                                  });
                                },
                          child: InputDecorator(
                            decoration: _inputDecoration(
                              label: 'Categoria',
                              icon: Icons.category,
                            ),
                            child: Text(
                              categoriaNome ?? 'Selecione uma categoria',
                              style: TextStyle(
                                color: categoriaNome == null
                                    ? Colors.grey.shade700
                                    : AppCores.preto,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
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
                              onTap: () {
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
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Nome do serviço',
                        icon: Icons.design_services_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descricaoController,
                      focusNode: descricaoFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      maxLines: 3,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Descrição',
                        icon: Icons.description,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      focusNode: precoFocus,
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                      ],
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Preço',
                        icon: Icons.attach_money,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarServico,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppCores.dourado,
                          foregroundColor: AppCores.preto,
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
                                'Adicionar Serviço',
                                style: TextStyle(
                                  color: AppCores.branco,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('servicos')
                    .orderBy('nomeBusca')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppCores.dourado),
                    );
                  }

                  if (snap.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar serviços',
                        style: TextStyle(color: AppCores.preto),
                      ),
                    );
                  }

                  final servicos = snap.data?.docs ?? [];

                  if (servicos.isEmpty) {
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
                              Icons.design_services_rounded,
                              size: 42,
                              color: AppCores.dourado.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum serviço cadastrado',
                              style: TextStyle(
                                color: AppCores.preto,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cadastre serviços para aparecer em sua categoria.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final Map<
                    String,
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  >
                  grupos = {};

                  for (final doc in servicos) {
                    final categoria =
                        doc.data()['categoriaNome']?.toString() ??
                        'Sem categoria';

                    if (!grupos.containsKey(categoria)) {
                      grupos[categoria] = [];
                    }

                    grupos[categoria]!.add(doc);
                  }

                  final categoriasOrdenadas = grupos.keys.toList()..sort();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categoriasOrdenadas.map((categoria) {
                      final itens = grupos[categoria] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Text(
                              categoria,
                              style: const TextStyle(
                                color: AppCores.dourado,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...itens.map((doc) {
                            final s = doc.data();
                            final id = doc.id;

                            final nome = s['nome']?.toString() ?? 'Serviço';
                            final categoriaNome =
                                s['categoriaNome']?.toString() ?? '';
                            final icone = iconeServicoPorCategoria(
                              categoriaNome,
                            );
                            final descricao =
                                s['descricao']?.toString().trim() ?? '';
                            final imagemUrl = s['imagemUrl']?.toString() ?? '';

                            return Container(
                              key: ValueKey(id),
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: AppCores.branco,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withOpacity(0.06),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 46,
                                      height: 46,
                                      decoration: BoxDecoration(
                                        color: AppCores.dourado.withOpacity(
                                          0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: imagemUrl.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              child: CachedNetworkImage(
                                                imageUrl: imagemUrl,

                                                width: 46,
                                                height: 46,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Center(
                                                      child: SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color: AppCores
                                                                  .dourado,
                                                            ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Icon(
                                                          icone,
                                                          color:
                                                              AppCores.dourado,
                                                        ),
                                              ),
                                            )
                                          : Icon(
                                              icone,
                                              color: AppCores.dourado,
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nome,
                                            softWrap: true,
                                            style: const TextStyle(
                                              color: AppCores.preto,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.5,
                                              height: 1.25,
                                            ),
                                          ),

                                          if (descricao.isNotEmpty) ...[
                                            const SizedBox(height: 5),
                                            Text(
                                              descricao,
                                              softWrap: true,
                                              style: const TextStyle(
                                                color: AppCores.preto,
                                                fontSize: 13,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            'R\$ ${formatarPreco(s['preco'])}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          GestureDetector(
                                            onTap: () async {
                                              final novoValor =
                                                  !(s['ativo'] ?? true);

                                              await FirebaseFirestore.instance
                                                  .collection('servicos')
                                                  .doc(id)
                                                  .update({
                                                    'ativo': novoValor,
                                                    'atualizadoEm':
                                                        FieldValue.serverTimestamp(),
                                                  });
                                            },
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 5,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: (s['ativo'] ?? true)
                                                    ? AppCores.dourado
                                                          .withOpacity(0.15)
                                                    : AppCores.branco
                                                          .withOpacity(0.06),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                border: Border.all(
                                                  color: (s['ativo'] ?? true)
                                                      ? AppCores.dourado
                                                            .withOpacity(0.35)
                                                      : AppCores.branco
                                                            .withOpacity(0.08),
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    (s['ativo'] ?? true)
                                                        ? Icons
                                                              .check_circle_rounded
                                                        : Icons.block_rounded,
                                                    size: 14,
                                                    color: (s['ativo'] ?? true)
                                                        ? AppCores.dourado
                                                        : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    (s['ativo'] ?? true)
                                                        ? 'Ativo'
                                                        : 'Inativo',
                                                    style: TextStyle(
                                                      color:
                                                          (s['ativo'] ?? true)
                                                          ? AppCores.dourado
                                                          : Colors.grey,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
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

                                              nomeFocus.unfocus();
                                              descricaoFocus.unfocus();
                                              precoFocus.unfocus();

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 200,
                                                ),
                                              );

                                              if (!context.mounted) return;

                                              await editarServico(id, s);
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

                                              nomeFocus.unfocus();
                                              descricaoFocus.unfocus();
                                              precoFocus.unfocus();

                                              await Future.delayed(
                                                const Duration(
                                                  milliseconds: 200,
                                                ),
                                              );

                                              if (!context.mounted) return;

                                              await removerServico(id, nome);

                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 14),
                        ],
                      );
                    }).toList(),
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../tema/app_cores.dart';

class GerenciarPlanosPage extends StatefulWidget {
  const GerenciarPlanosPage({super.key});

  @override
  State<GerenciarPlanosPage> createState() => _GerenciarPlanosPageState();
}

class _GerenciarPlanosPageState extends State<GerenciarPlanosPage> {
  final nomeFocus = FocusNode();
  final descricaoFocus = FocusNode();
  final precoFocus = FocusNode();

  final nomeController = TextEditingController();
  final descricaoController = TextEditingController();
  final precoController = TextEditingController();

  bool carregando = false;

  String normalizarNome(String nome) {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  double? converterPreco(String valor) {
    final normalizado = valor.trim().replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(normalizado);
  }

  void mostrarMensagem(String mensagem, Color cor) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem), backgroundColor: cor));
  }

  Future<void> adicionarPlano() async {
    if (carregando) return;

    FocusScope.of(context).unfocus();

    final nome = nomeController.text.trim();
    final descricao = descricaoController.text.trim();
    final precoTexto = precoController.text.trim();
    final preco = converterPreco(precoTexto);

    if (nome.isEmpty || descricao.isEmpty) {
      mostrarMensagem('Preencha todos os campos', Colors.red);
      return;
    }

    if (preco == null || preco <= 0) {
      mostrarMensagem('Digite um preço válido maior que zero', Colors.red);
      return;
    }

    setState(() => carregando = true);

    try {
      final nomeBusca = normalizarNome(nome);

      final planoExistente = await FirebaseFirestore.instance
          .collection('planos')
          .where('nomeBusca', isEqualTo: nomeBusca)
          .limit(1)
          .get();

      if (planoExistente.docs.isNotEmpty) {
        mostrarMensagem('Já existe um plano com esse nome', Colors.red);

        setState(() => carregando = false);

        return;
      }

      await FirebaseFirestore.instance.collection('planos').add({
        'nome': nome,
        'nomeBusca': nomeBusca,
        'descricao': descricao,
        'preco': preco,
        'ativo': true,
        'periodo': 'mensal',
        'versao': 1,
        'gateway': 'asaas',
        'criadoEm': FieldValue.serverTimestamp(),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      nomeController.clear();
      descricaoController.clear();
      precoController.clear();

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();

      mostrarMensagem('Plano cadastrado com sucesso', Colors.green);
    } catch (e) {
      mostrarMensagem('Erro ao salvar plano', Colors.red);
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<void> alterarStatusPlano({
    required String id,
    required String nome,
    required bool ativoAtual,
  }) async {
    final novoStatus = !ativoAtual;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: AppCores.branco,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            novoStatus ? 'Reativar plano' : 'Desativar plano',
            style: const TextStyle(color: AppCores.preto),
          ),
          content: Text(
            novoStatus
                ? 'Deseja reativar "$nome"? Ele voltará a aparecer para os clientes.'
                : 'Deseja desativar "$nome"? Ele não aparecerá mais para novos clientes.',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: AppCores.dourado,
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: novoStatus ? Colors.green : Colors.redAccent,
                foregroundColor: AppCores.branco,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(novoStatus ? 'Reativar' : 'Desativar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('planos').doc(id).update({
        'ativo': novoStatus,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      mostrarMensagem(
        novoStatus ? 'Plano reativado' : 'Plano desativado',
        novoStatus ? Colors.green : Colors.orange,
      );
    } catch (_) {
      mostrarMensagem('Erro ao alterar status do plano', Colors.red);
    }
  }

  Future<void> excluirPlanoDesativado(
    String id,
    String nome,
    bool ativo,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (ativo) {
      mostrarMensagem('Desative o plano antes de excluir', Colors.orange);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppCores.branco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Excluir plano',
          style: TextStyle(color: AppCores.branco),
        ),
        content: Text(
          'Deseja realmente excluir "$nome"?',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppCores.dourado,
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: AppCores.branco,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await FirebaseFirestore.instance.collection('planos').doc(id).delete();

      mostrarMensagem('Plano excluído com sucesso', Colors.green);

      nomeFocus.unfocus();
      descricaoFocus.unfocus();
      precoFocus.unfocus();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (_) {
      mostrarMensagem('Erro ao excluir plano', Colors.red);
    }
  }

  Future<void> editarPlano(String id, Map<String, dynamic> dados) async {
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

    final salvar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppCores.branco,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Editar plano',
          style: TextStyle(color: AppCores.branco),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCtrl,
                style: const TextStyle(color: AppCores.preto),
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descricaoCtrl,
                maxLines: 3,
                style: const TextStyle(color: AppCores.preto),
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                ],
                style: const TextStyle(color: AppCores.preto),
                decoration: const InputDecoration(
                  labelText: 'Preço',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: AppCores.dourado,
            ),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppCores.dourado,
              foregroundColor: AppCores.preto,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvar != true) return;

    final nome = nomeCtrl.text.trim();
    final descricao = descricaoCtrl.text.trim();
    final preco = converterPreco(precoCtrl.text);

    if (nome.isEmpty || descricao.isEmpty || preco == null || preco <= 0) {
      mostrarMensagem('Preencha todos os dados corretamente', Colors.red);
      return;
    }

    try {
      final nomeBusca = normalizarNome(nome);

      final existente = await FirebaseFirestore.instance
          .collection('planos')
          .where('nomeBusca', isEqualTo: nomeBusca)
          .limit(1)
          .get();

      if (existente.docs.isNotEmpty && existente.docs.first.id != id) {
        mostrarMensagem('Já existe um plano com esse nome', Colors.red);
        return;
      }

      await FirebaseFirestore.instance.collection('planos').doc(id).update({
        'nome': nome,
        'nomeBusca': nomeBusca,
        'descricao': descricao,
        'preco': preco,
        'versao': FieldValue.increment(1),
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      mostrarMensagem('Plano atualizado com sucesso', Colors.green);
    } catch (e) {
      mostrarMensagem('Erro ao atualizar plano', Colors.red);
    }
  }

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    return '0,00';
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Gerenciar Planos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: nomeController,
                      focusNode: nomeFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Nome do plano',
                        icon: Icons.workspace_premium_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descricaoController,
                      focusNode: descricaoFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Descrição',
                        icon: Icons.description_outlined,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: precoController,
                      focusNode: precoFocus,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9,\.]')),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (!carregando) adicionarPlano();
                      },
                      style: const TextStyle(color: AppCores.preto),
                      decoration: _inputDecoration(
                        label: 'Preço',
                        icon: Icons.attach_money_rounded,
                      ),
                    ),

                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: carregando ? null : adicionarPlano,
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
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: AppCores.preto,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Salvar Plano',
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
                    .collection('planos')
                    .orderBy('nomeBusca')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text(
                        'Erro ao carregar planos',
                      style: TextStyle(color: AppCores.preto),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (snapshot.data?.docs.isEmpty ?? true)) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppCores.dourado),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
                              Icons.workspace_premium_rounded,
                              size: 42,
                              color: AppCores.dourado.withOpacity(0.9),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Nenhum plano cadastrado',
                              style: TextStyle(
                                color: AppCores.branco,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cadastre um plano para disponibilizar assinaturas.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final planos = snapshot.data!.docs;

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: planos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = planos[index];
                      final plano = doc.data();

                      final nome = plano['nome']?.toString().trim() ?? '';
                      final descricao =
                          plano['descricao']?.toString().trim() ?? '';
                      final preco = formatarPreco(plano['preco']);
                      final ativo = plano['ativo'] ?? true;

                      return Container(
                        key: ValueKey(doc.id),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: AppCores.branco,
                          border: Border.all(
                            color: Colors.black.withOpacity(0.06),
                          ),
                          boxShadow: [
                            BoxShadow(
                             color: Colors.black.withOpacity(0.06),
blurRadius: 12,
offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: AppCores.dourado.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium_rounded,
                                    color: AppCores.dourado,
                                    size: 25,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nome.isEmpty ? 'Plano sem nome' : nome,
                                        style: const TextStyle(
                                          color: AppCores.branco,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (descricao.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          descricao,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
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
                                            const Duration(milliseconds: 200),
                                          );

                                          if (!context.mounted) return;
                                          await editarPlano(doc.id, plano);
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
                                        iconSize: 25,
                                        icon: Icon(
                                          ativo
                                              ? Icons.toggle_off_rounded
                                              : Icons.toggle_on_rounded,
                                          color: ativo
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        onPressed: () async {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                          nomeFocus.unfocus();
                                          descricaoFocus.unfocus();
                                          precoFocus.unfocus();

                                          await Future.delayed(
                                            const Duration(milliseconds: 200),
                                          );

                                          if (!context.mounted) return;
                                          await alterarStatusPlano(
                                            id: doc.id,
                                            nome: nome,
                                            ativoAtual: ativo,
                                          );
                                        },
                                      ),
                                    ),
                                    if (!ativo) ...[
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
                                              const Duration(milliseconds: 200),
                                            );

                                            if (!context.mounted) return;
                                            await excluirPlanoDesativado(
                                              doc.id,
                                              nome,
                                              ativo,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'R\$ $preco',
                                  style: const TextStyle(
                                    color: AppCores.dourado,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Mensal',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ativo
                                        ? Colors.green.withOpacity(0.18)
                                        : Colors.red.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    ativo ? 'ATIVO' : 'DESATIVADO',
                                    style: TextStyle(
                                      color: ativo
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import '../tema/app_cores.dart';

class PlanosPage extends StatefulWidget {
  const PlanosPage({super.key});

  @override
  State<PlanosPage> createState() => _PlanosPageState();
}

class _PlanosPageState extends State<PlanosPage> {
  String? planoCarregandoId;

  String formatarPreco(dynamic valor) {
    if (valor == null) return '0,00';

    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    if (valor == null) return '0,00';
    final preco = double.tryParse(valor.toString());
    if (preco == null) return '0,00';

    return preco.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<String> buscarNomeUsuario(User user) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(user.uid)
          .get();

      final nome = doc.data()?['nome']?.toString().trim();

      if (nome != null && nome.isNotEmpty) {
        return nome;
      }

      if ((user.displayName ?? '').trim().isNotEmpty) {
        return user.displayName!.trim();
      }

      return 'Cliente';
    } catch (_) {
      return user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : 'Cliente';
    }
  }

  Future<void> solicitarAssinatura({
    required BuildContext context,
    required String planoId,
    required Map<String, dynamic> plano,
  }) async {
    if (planoCarregandoId != null) return;

    setState(() => planoCarregandoId = planoId);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuário não logado');

      // 🔥 VERIFICA SE JÁ TEM PLANO ATIVO
      final assinaturaSnapshot = await FirebaseFirestore.instance
          .collection('assinaturas_planos')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['ativa', 'cancelamento_agendado'])
          .limit(1)
          .get();

      if (assinaturaSnapshot.docs.isNotEmpty) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já possui uma assinatura ativa.'),
            backgroundColor: Colors.orange,
          ),
        );

        setState(() => planoCarregandoId = null);
        return;
      }
      final nomeUsuario = await buscarNomeUsuario(user);

      final callable = FirebaseFunctions.instance.httpsCallable(
        'criarAssinatura',
      );

      final preco = plano['preco'] is num
          ? (plano['preco'] as num).toDouble()
          : double.tryParse(plano['preco'].toString()) ?? 0.0;

      final resultado = await callable.call({
        'planoId': planoId,
        'planoNome': plano['nome'],
        'planoDescricao': plano['descricao'] ?? '',
        'valor': preco,
        'email': user.email ?? '',
        'nome': nomeUsuario,
      });

      final checkoutUrl = resultado.data['checkoutUrl']?.toString() ?? '';

      if (checkoutUrl.isEmpty) {
        throw Exception('Checkout do Asaas não foi gerado.');
      }

      final uri = Uri.parse(checkoutUrl);

      final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!abriu) {
        throw Exception('Não foi possível abrir o checkout.');
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Finalize o pagamento para ativar seu plano.'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Erro ao criar checkout'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => planoCarregandoId = null);
      }
    }
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppCores.branco,
        borderRadius: BorderRadius.circular(26),
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
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: const Color.fromRGBO(234, 219, 195, 1),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppCores.dourado,
              size: 36,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Escolha seu plano',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppCores.preto,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Assinatura mensal para serviços exclusivos e descontos especiais. \n \n Cancele quando quiser.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _planoCard({
    required BuildContext context,
    required String id,
    required Map<String, dynamic> plano,
    required bool bloqueadoPorAssinatura,
  }) {
    final nome = plano['nome']?.toString().trim() ?? '';
    final descricao = plano['descricao']?.toString().trim() ?? '';
    final preco = formatarPreco(plano['preco']);
    final carregando = planoCarregandoId == id;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppCores.branco,
        borderRadius: BorderRadius.circular(26),
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
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(234, 219, 195, 1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: AppCores.dourado,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nome.isEmpty ? 'Plano' : nome,
                  style: const TextStyle(
                    color: AppCores.preto,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (descricao.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              descricao,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppCores.fundoClaro,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color.fromRGBO(176, 125, 6, 0.18)),
            ),
            child: Column(
              children: [
                Text(
                  'R\$ $preco',
                  style: const TextStyle(
                    color: AppCores.dourado,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Por mês',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: bloqueadoPorAssinatura
                  ? null
                  : planoCarregandoId == null
                  ? () {
                      solicitarAssinatura(
                        context: context,
                        planoId: id,
                        plano: plano,
                      );
                    }
                  : null,
              icon: carregando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppCores.preto,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.workspace_premium_rounded),
              label: Text(
                bloqueadoPorAssinatura
                    ? 'Você já possui um plano'
                    : carregando
                    ? 'Aguarde...'
                    : 'Assinar agora',
                style: const TextStyle(color: AppCores.branco, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppCores.dourado,
                foregroundColor: AppCores.preto,
                disabledBackgroundColor: AppCores.dourado.withOpacity(0.55),
                disabledForegroundColor: AppCores.preto,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppCores.branco,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withOpacity(0.06)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 48,
              color: AppCores.dourado.withOpacity(0.9),
            ),
            const SizedBox(height: 12),
            const Text(
              'Nenhum plano disponível',
              style: TextStyle(
                color: AppCores.preto,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Os planos aparecerão aqui em breve.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Planos de Assinatura',
          style: TextStyle(
            color: AppCores.preto,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppCores.preto,
        iconTheme: const IconThemeData(color: AppCores.preto),
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('assinaturas_planos')
                  .where('userId', isEqualTo: user?.uid ?? '')
                  .where('status', whereIn: ['ativa', 'cancelamento_agendado'])
                  .limit(1)
                  .snapshots(),
              builder: (context, assinaturaSnapshot) {
                final bloqueadoPorAssinatura =
                    assinaturaSnapshot.data?.docs.isNotEmpty == true;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('planos')
                      .where('ativo', isEqualTo: true)
                      .orderBy('criadoEm', descending: true)
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

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppCores.dourado,
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyState();
                    }

                    final planos = snapshot.data!.docs;

                    return ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: planos.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        if (index == 0) return _header();

                        final doc = planos[index - 1];

                        return Container(
                          key: ValueKey(doc.id),
                          child: _planoCard(
                            context: context,
                            id: doc.id,
                            plano: doc.data(),
                            bloqueadoPorAssinatura: bloqueadoPorAssinatura,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'agendamento.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../tema/app_cores.dart';

class CategoriaServicosPage extends StatelessWidget {
  final String categoriaId;
  final String categoriaNome;
  final IconData icone;

  const CategoriaServicosPage({
    super.key,
    required this.categoriaId,
    required this.categoriaNome,
    required this.icone,
  });

  String formatarPreco(dynamic valor) {
    if (valor is num) {
      return valor.toDouble().toStringAsFixed(2).replaceAll('.', ',');
    }

    if (valor == null) return '0,00';

    final preco = double.tryParse(valor.toString().replaceAll(',', '.')) ?? 0;
    return preco.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     backgroundColor: AppCores.fundoClaro,
      appBar: AppBar(
        title: Text(categoriaNome),
        centerTitle: true,
       backgroundColor: AppCores.fundoClaro,
        elevation: 0,
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('servicos')
              .where('categoriaId', isEqualTo: categoriaId)
              .where('ativo', isEqualTo: true)
              .orderBy('nomeBusca')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Erro ao carregar serviços',
                 style: TextStyle(color: AppCores.preto),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppCores.dourado),
              );
            }

            final servicos = snapshot.data?.docs ?? [];

            if (servicos.isEmpty) {
              return const Center(
                child: Text(
                  'Nenhum serviço nesta categoria',
               style: TextStyle(color: AppCores.preto),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: servicos.length,
              itemBuilder: (context, index) {
                final item = servicos[index].data();
                final servicoId = servicos[index].id;
                final nome = item['nome']?.toString().trim() ?? 'Serviço';
                final imagemUrl = item['imagemUrl']?.toString() ?? '';
                final descricao = item['descricao']?.toString().trim() ?? '';
                final preco = formatarPreco(item['preco']);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AgendamentoPage(
                            servicoSelecionado: nome,
                            servicoIdSelecionado: servicoId,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                       color: AppCores.preto,
                        border: Border.all(
                         color: Colors.black.withOpacity(0.06),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                             color: const Color.fromRGBO(234, 219, 195, 1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: imagemUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: CachedNetworkImage(
                                      imageUrl: imagemUrl,

                                      fit: BoxFit.cover,
                                      width: 52,
                                      height: 52,
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppCores.dourado,
                                              ),
                                            ),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          Icon(icone, color: AppCores.dourado),
                                    ),
                                  )
                                : Icon(icone, color: AppCores.dourado),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nome,
                                  style: const TextStyle(
                                    color: AppCores.branco,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (descricao.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    descricao,
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  'R\$ $preco',
                                  style: const TextStyle(
                                    color: AppCores.dourado,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
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

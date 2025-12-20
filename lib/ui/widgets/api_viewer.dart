import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/api_exchange.dart';

class ApiViewer extends StatelessWidget {
  final ApiExchange exchange;

  const ApiViewer({super.key, required this.exchange});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Dialog(
        child: Container(
          width: double.maxFinite,
          height: 500,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${exchange.method} ${exchange.url}',
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${exchange.statusCode}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: exchange.statusCode >= 200 && exchange.statusCode < 300
                      ? Colors.green
                      : Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const TabBar(
                tabs: [
                  Tab(text: 'Request'),
                  Tab(text: 'Response'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _buildContent(
                      exchange.requestHeaders,
                      exchange.requestBody,
                    ),
                    _buildContent(
                      exchange.responseHeaders,
                      exchange.responseBody,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, String> headers, String body) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            color: Colors.grey[200],
            child: const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: 'Headers'),
                Tab(text: 'Body'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHeadersView(headers),
                _buildBodyView(body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadersView(Map<String, String> headers) {
    final censoredHeaders = Map<String, String>.from(headers);
    if (censoredHeaders.containsKey('Authorization')) {
      censoredHeaders['Authorization'] = 'Bearer [REDACTED]';
    }
    if (censoredHeaders.containsKey('X-Goog-Api-Key')) {
      censoredHeaders['X-Goog-Api-Key'] = '[REDACTED]';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: SelectableText(
        censoredHeaders.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n'),
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildBodyView(String body) {
    String displayBody = body;
    try {
      if (body.isNotEmpty) {
        final json = jsonDecode(body);
        const encoder = JsonEncoder.withIndent('  ');
        displayBody = encoder.convert(json);
      }
    } catch (_) {
      // Not JSON, display as is
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8.0),
      child: SelectableText(
        displayBody,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }
}

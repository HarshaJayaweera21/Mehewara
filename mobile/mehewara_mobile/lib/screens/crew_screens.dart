import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/network/api_client.dart';
import '../models/work_order.dart';
import '../services/auth/auth_service.dart';
import '../services/work_orders/work_order_service.dart';

String statusLabel(String text) => text.replaceAll('_', ' ');
String dateLabel(DateTime? date) =>
    date == null ? 'Not yet' : date.toLocal().toString().split('.').first;

class CrewLogin extends StatefulWidget {
  final CrewSession session;
  const CrewLogin({super.key, required this.session});
  @override
  State<CrewLogin> createState() => _CrewLoginState();
}

class _CrewLoginState extends State<CrewLogin> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, obscured = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.session.login(email.text, password.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.engineering,
                    size: 64,
                    color: Color(0xff087f8c),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Mehewara Crew',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to manage your crew’s jobs.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  if (error != null || widget.session.error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        error ?? widget.session.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username],
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => v == null || !v.contains('@')
                        ? 'Enter your email.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    obscureText: obscured,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        tooltip: obscured ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => obscured = !obscured),
                        icon: Icon(
                          obscured ? Icons.visibility : Icons.visibility_off,
                        ),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your password.' : null,
                    onFieldSubmitted: (_) => submit(),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Text(busy ? 'Signing in…' : 'Sign in'),
                    ),
                  ),
                  if (widget.session.api.token != null)
                    TextButton(
                      onPressed: busy ? null : widget.session.restore,
                      child: const Text('Retry saved session'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CrewJobs extends StatefulWidget {
  final CrewSession session;
  const CrewJobs({super.key, required this.session});
  @override
  State<CrewJobs> createState() => _CrewJobsState();
}

class _CrewJobsState extends State<CrewJobs> with WidgetsBindingObserver {
  late final WorkOrderService service = WorkOrderService(widget.session.api);
  WorkOrderPage? data;
  WorkOrder? selected;
  String filter = '', notesFor = '';
  String? error, detailError, notice;
  int page = 1, listVersion = 0, detailVersion = 0;
  bool loading = true, detailLoading = false, busy = false;
  final notes = TextEditingController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void dispose() {
    listVersion++;
    detailVersion++;
    WidgetsBinding.instance.removeObserver(this);
    notes.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !busy) {
      load();
      if (selected != null) loadDetail(selected!.id);
    }
  }

  Future<void> load() async {
    final version = ++listVersion;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await service.list(page: page, status: filter);
      if (mounted && version == listVersion) setState(() => data = result);
    } catch (e) {
      if (mounted && version == listVersion) {
        setState(() {
          error = e.toString();
          data = null;
        });
      }
    } finally {
      if (mounted && version == listVersion) setState(() => loading = false);
    }
  }

  Future<void> loadDetail(String id) async {
    final version = ++detailVersion;
    setState(() {
      detailLoading = true;
      detailError = null;
    });
    try {
      final result = await service.detail(id);
      if (mounted && version == detailVersion) {
        setState(() => selected = result);
      }
    } catch (e) {
      if (mounted && version == detailVersion) {
        setState(() {
          detailError = e.toString();
          selected = null;
        });
      }
    } finally {
      if (mounted && version == detailVersion) {
        setState(() => detailLoading = false);
      }
    }
  }

  Future<void> transition(bool complete) async {
    if (busy || selected == null) return;
    setState(() {
      busy = true;
      detailError = null;
      notice = null;
    });
    try {
      final result = complete
          ? await service.complete(selected!.id, notes.text)
          : await service.start(selected!.id);
      if (!mounted) return;
      setState(() {
        selected = result;
        notes.clear();
        notice = complete ? 'Job completed. Thank you.' : 'Job started.';
      });
      await load();
    } catch (e) {
      if (!mounted) return;
      if (e is ApiException && e.status == 409) {
        await Future.wait([load(), loadDetail(notesFor)]);
        if (mounted) {
          setState(
            () =>
                notice = 'This job changed. The latest status has been loaded.',
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice!)));
        }
      } else {
        setState(() => detailError = e.toString());
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void back() {
    detailVersion++;
    setState(() {
      selected = null;
      notesFor = '';
      detailError = null;
      notice = null;
      detailLoading = false;
      notes.clear();
    });
    load();
  }

  @override
  Widget build(BuildContext context) {
    final showingDetail = notesFor.isNotEmpty;
    return PopScope(
      canPop: !showingDetail,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy) back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(showingDetail ? 'Job details' : 'My Jobs'),
          leading: showingDetail
              ? IconButton(
                  tooltip: 'Back to jobs',
                  onPressed: busy ? null : back,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: busy
                  ? null
                  : () {
                      load();
                      if (showingDetail) loadDetail(notesFor);
                    },
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: busy ? null : widget.session.logout,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: SafeArea(
          child: showingDetail ? detailView(context) : listView(context),
        ),
      ),
    );
  }

  Widget listView(BuildContext context) => RefreshIndicator(
    onRefresh: load,
    child: ListView(
      padding: const EdgeInsets.all(20),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'Hello, ${widget.session.user?['firstName'] ?? widget.session.user?['name'] ?? 'crew leader'}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Your crew’s assignments and completed work.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: filter,
          decoration: const InputDecoration(labelText: 'Job status'),
          items: ['', 'ASSIGNED', 'IN_PROGRESS', 'COMPLETED']
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? 'All jobs' : statusLabel(s)),
                ),
              )
              .toList(),
          onChanged: (s) {
            setState(() {
              filter = s!;
              page = 1;
            });
            load();
          },
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) errorBox(error!, load),
        if (!loading && data?.items.isEmpty == true)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text(
              'No jobs match this filter.',
              textAlign: TextAlign.center,
            ),
          ),
        ...?data?.items.map(
          (job) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  notesFor = job.id;
                  selected = null;
                  notice = null;
                  notes.clear();
                });
                loadDetail(job.id);
              },
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(label: Text(job.priority)),
                        Chip(label: Text(statusLabel(job.status))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(job.address ?? job.problemTitle),
                    const SizedBox(height: 12),
                    Text(
                      job.crewName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: loading || page <= 1
                  ? null
                  : () {
                      setState(() => page--);
                      load();
                    },
              child: const Text('Previous'),
            ),
            Text(
              'Page $page of ${(data?.totalPages ?? 0) < 1 ? 1 : data!.totalPages}',
            ),
            TextButton(
              onPressed: loading || data == null || page >= data!.totalPages
                  ? null
                  : () {
                      setState(() => page++);
                      load();
                    },
              child: const Text('Next'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget errorBox(String text, VoidCallback retry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(color: Colors.red)),
        TextButton(onPressed: retry, child: const Text('Retry')),
      ],
    ),
  );

  Widget detailView(BuildContext context) {
    final job = selected;
    return RefreshIndicator(
      onRefresh: () => loadDetail(notesFor),
      child: ListView(
        padding: const EdgeInsets.all(22),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (detailLoading) const LinearProgressIndicator(),
          if (detailError != null)
            errorBox(detailError!, () => loadDetail(notesFor)),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                notice!,
                style: const TextStyle(color: Color(0xff087f8c)),
              ),
            ),
          if (job != null) ...[
            Wrap(
              spacing: 8,
              children: [
                Chip(label: Text(job.priority)),
                Chip(label: Text(statusLabel(job.status))),
              ],
            ),
            Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text(job.crewName),
            const Divider(height: 32),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(job.address ?? 'Address unavailable'),
            Text('${job.latitude}, ${job.longitude}'),
            TextButton.icon(
              onPressed: () async {
                try {
                  final opened = await launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${job.latitude},${job.longitude}',
                    ),
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened && mounted) {
                    setState(
                      () => detailError = 'Could not open Maps. Use the coordinates shown above.',
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    setState(() => detailError = 'Could not open Maps.');
                  }
                }
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in Maps'),
            ),
            const SizedBox(height: 12),
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(job.instructions ?? 'No additional instructions.'),
            const SizedBox(height: 20),
            Text(
              'Assigned: ${dateLabel(job.assignedAt)}\nStarted: ${dateLabel(job.startedAt)}\nCompleted: ${dateLabel(job.completedAt)}',
              style: const TextStyle(height: 1.8),
            ),
            if (job.completionNotes != null) ...[
              const SizedBox(height: 20),
              Text(
                'Completion notes',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(job.completionNotes!),
            ],
            const SizedBox(height: 24),
            if (job.status == 'ASSIGNED')
              FilledButton(
                onPressed: busy || detailLoading
                    ? null
                    : () => transition(false),
                child: Text(busy ? 'Starting…' : 'Start Job'),
              ),
            if (job.status == 'IN_PROGRESS') ...[
              TextField(
                controller: notes,
                enabled: !busy,
                maxLength: 4000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Completion notes (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              FilledButton(
                onPressed: busy || detailLoading
                    ? null
                    : () => transition(true),
                child: Text(busy ? 'Completing…' : 'Complete Job'),
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Activity history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (job.history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No execution events recorded yet.'),
              ),
            ...job.history.map(
              (a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.history),
                title: Text(statusLabel(a.action)),
                subtitle: Text(
                  '${dateLabel(a.createdAt)}${a.note == null ? '' : '\n${a.note}'}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            SelectableText(
              'Job ID: ${job.id}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

import '../models.dart';
import '../services.dart';
import 'integration_provider.dart';

class GitHubProvider implements IntegrationProvider {
  GitHubProvider({GitHubService? service})
      : _service = service ?? GitHubService();

  final GitHubService _service;

  @override
  String get id => 'github';

  @override
  String get displayName => 'GitHub';

  @override
  IntegrationCategory get category => IntegrationCategory.codeReview;

  @override
  String get logoAsset => 'assets/logos/github.svg';

  @override
  bool isConfigured(ConnectorConfig config) => config.isGitHubConfigured;

  @override
  Future<List<IntegrationItem>> fetchItems(ConnectorConfig config) async {
    final List<GithubPullRequest> prs = await _service.fetchPendingReviews(
      username: config.githubUsername,
      token: config.githubToken,
    );
    return prs.map(_mapPullRequest).toList();
  }

  GitHubService get service => _service;

  static IntegrationItem _mapPullRequest(GithubPullRequest pr) {
    return IntegrationItem(
      id: pr.id,
      providerId: 'github',
      category: IntegrationCategory.codeReview,
      title: pr.title,
      subtitle: '${pr.repository} #${pr.number}',
      url: pr.url,
      timestamp: pr.updatedAt,
      reason: ItemReason.reviewRequested,
      metadata: <String, dynamic>{
        'owner': pr.owner,
        'repo': pr.repo,
        'number': pr.number,
        'author': pr.author,
        'draft': pr.draft,
        'headBranch': pr.headBranch,
        'changedFiles': pr.changedFiles,
        'additions': pr.additions,
        'deletions': pr.deletions,
        'labels': pr.labels,
        'summary': pr.summary,
        'repository': pr.repository,
        'body': pr.body,
        'commits': pr.commits,
      },
    );
  }

  static GithubPullRequest pullRequestFromItem(IntegrationItem item) {
    return GithubPullRequest(
      id: item.id,
      owner: item.meta<String>('owner') ?? '',
      repo: item.meta<String>('repo') ?? '',
      number: item.meta<int>('number') ?? 0,
      title: item.title,
      author: item.meta<String>('author') ?? '',
      url: item.url,
      updatedAt: item.timestamp,
      draft: item.meta<bool>('draft') ?? false,
      headBranch: item.meta<String>('headBranch'),
      changedFiles: item.meta<int>('changedFiles') ?? 0,
      additions: item.meta<int>('additions') ?? 0,
      deletions: item.meta<int>('deletions') ?? 0,
      labels: (item.metadata['labels'] as List<dynamic>?)
              ?.map((dynamic l) => l.toString())
              .toList() ??
          const <String>[],
      summary: item.meta<String>('summary'),
      body: item.meta<String>('body') ?? '',
      commits: item.meta<int>('commits') ?? 0,
    );
  }
}

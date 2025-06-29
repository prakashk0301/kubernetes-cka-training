# Helm Concepts

#### Helm installs charts into Kubernetes, creating a new release for each installation. To find new charts, you can search Helm chart repositories.

---

## Chart
A **Chart** is a Helm package. It contains all of the resource definitions necessary to run an application, tool, or service inside of a Kubernetes cluster. Think of it like the Kubernetes equivalent of a Homebrew formula, an Apt dpkg, or a Yum RPM file.

## Repository
A **Repository** is the place where charts can be collected and shared. It’s like Perl’s CPAN archive or the Fedora Package Database, but for Kubernetes packages.

## Release
A **Release** is an instance of a chart running in a Kubernetes cluster. One chart can often be installed many times into the same cluster. Each time it is installed, a new release is created. For example, if you want two MySQL databases running in your cluster, you can install the MySQL chart twice. Each one will have its own release and release name.

---

## Helm CLI Command Reference

Below is a summary of common Helm CLI commands:

| Command      | Description |
|--------------|-------------|
| `completion` | Generate autocompletion scripts for the specified shell |
| `create`     | Create a new chart with the given name |
| `dependency` | Manage a chart's dependencies |
| `env`        | Helm client environment information |
| `get`        | Download extended information of a named release |
| `help`       | Help about any command |
| `history`    | Fetch release history |
| `install`    | Install a chart |
| `lint`       | Examine a chart for possible issues |
| `list`       | List releases |
| `package`    | Package a chart directory into a chart archive |
| `plugin`     | Install, list, or uninstall Helm plugins |
| `pull`       | Download a chart from a repository and (optionally) unpack it in local directory |
| `push`       | Push a chart to remote |
| `registry`   | Login to or logout from a registry |
| `repo`       | Add, list, remove, update, and index chart repositories |
| `rollback`   | Roll back a release to a previous revision |
| `search`     | Search for a keyword in charts |
| `show`       | Show information of a chart |
| `status`     | Display the status of the named release |
| `template`   | Locally render templates |
| `test`       | Run tests for a release |
| `uninstall`  | Uninstall a release |
| `upgrade`    | Upgrade a release |
| `verify`     | Verify that a chart at the given path has been signed and is valid |
| `version`    | Print the client version information |

---

> For more details, see the [Helm documentation](https://helm.sh/docs/).
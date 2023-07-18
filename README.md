# On-demand self-hosted Azure Virtual Machines runner for GitHub Actions

Start your Azure Virtual Machines self-hosted runner right before you need it. Run the job on it. Finally, stop it when you finish. And all this automatically as a part of your GitHub Actions workflow.

## Exemple

A workflow do-the-job.yml looks like this:

```yaml
name: do-the-job
on: push
jobs:
  start-runner:
    uses: logiroad/azure-github-runner/.github/workflows/create.yml@main
      with:
        VM_SIZE: Standard_B1s
        LOCATION: northeurope
      secrets:
        ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
        ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
        ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
        ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
        GH_TOKEN: ${{ secrets.GH_TOKEN }}
  do-the-job:
    needs: start-runner # required to start the main job when the runner is ready
        runs-on: ${{ needs.create.outputs.uniq_label }} # run the job on the newly created runner
        steps:
          - name: Hello World
            run: echo 'Hello World from Azure!'
  stop-runner:
    needs: do-the-job # required to wait when the main job is done
    uses: logiroad/azure-github-runner/.github/workflows/delete.yml@main
    if: ${{ always() }} # required to stop the runner even if the error happened in the previous jobs
    secrets:
      ARM_CLIENT_ID: ${{ secrets.ARM_CLIENT_ID }}
      ARM_CLIENT_SECRET: ${{ secrets.ARM_CLIENT_SECRET }}
      ARM_TENANT_ID: ${{ secrets.ARM_TENANT_ID }}
      ARM_SUBSCRIPTION_ID: ${{ secrets.ARM_SUBSCRIPTION_ID }}
      GH_TOKEN: ${{ secrets.GH_TOKEN }}
```

You also have an exemple at [test_create.yml](.github/workflows/test_create.yml)
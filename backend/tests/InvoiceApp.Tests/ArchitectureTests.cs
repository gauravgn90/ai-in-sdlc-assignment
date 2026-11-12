using InvoiceApp.Api;
using InvoiceApp.Api.Controllers;
using NetArchTest.Rules;
using Xunit;

namespace InvoiceApp.Tests;

/// <summary>
/// Layering rules from AGENTS.md, checked against the compiled assemblies.
/// </summary>
public class ArchitectureTests
{
    private const string ControllersNamespace = "InvoiceApp.Api.Controllers";

    [Fact]
    public void Controllers_DoNotDependOnTheConcreteInvoiceStore()
    {
        var controllers = Types.InAssembly(typeof(ApiControllerBase).Assembly)
            .That()
            .ResideInNamespace(ControllersNamespace);

        // Guard against a rule that passes because it selected nothing.
        Assert.NotEmpty(controllers.GetTypes());

        var result = controllers
            .ShouldNot()
            .HaveDependencyOn(typeof(InMemoryInvoiceRepository).FullName)
            .GetResult();

        var offenders = string.Join(", ", result.FailingTypeNames ?? Array.Empty<string>());
        Assert.True(
            result.IsSuccessful,
            $"Controllers must go through IInvoiceRepository or ApprovalService, not the store. Offending types: {offenders}");
    }
}

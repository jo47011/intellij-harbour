package org.intellij.sdk.language;

import com.intellij.ide.structureView.StructureViewTreeElement;
import com.intellij.ide.util.treeView.smartTree.SortableTreeElement;
import com.intellij.ide.util.treeView.smartTree.TreeElement;
import com.intellij.navigation.ItemPresentation;
import com.intellij.navigation.NavigationItem;
import com.intellij.openapi.diagnostic.Logger;
import com.intellij.openapi.util.text.StringUtil;
import com.intellij.psi.PsiElement;
import com.intellij.psi.PsiFile;
import com.intellij.psi.impl.source.tree.LeafPsiElement;
import com.intellij.psi.util.PsiTreeUtil;
import org.intellij.sdk.language.psi.HarbourFile;
import org.jetbrains.annotations.NotNull;

import javax.swing.*;
import java.util.*;

/**
 * Structure View Element for Harbour files - token-based implementation
 * with support for method implementations
 */
public class HarbourStructureViewElement implements StructureViewTreeElement, SortableTreeElement {
    private static final Logger LOG = Logger.getInstance(HarbourStructureViewElement.class);

    private final PsiElement element;
    private final String elementType;
    private final String elementName;
    private final HarbourStructureViewElement parent;
    private final List<HarbourStructureViewElement> children = new ArrayList<>();

    private static final String PROCEDURE_TOKEN = "HarbourTokenType.PROCEDURE";
    private static final String FUNCTION_TOKEN = "HarbourTokenType.FUNCTION";
    private static final String METHOD_TOKEN = "HarbourTokenType.METHOD";
    private static final String CLASS_TOKEN = "HarbourTokenType.CLASS";
    private static final String ENDCLASS_TOKEN = "HarbourTokenType.ENDCLASS";
    private static final String DATA_TOKEN = "HarbourTokenType.DATA";

    // Implementation type flag
    private final boolean isImplementation;

    public HarbourStructureViewElement(PsiElement element) {
        this(element, null, false);
    }

    public HarbourStructureViewElement(PsiElement element, HarbourStructureViewElement parent) {
        this(element, parent, false);
    }

    public HarbourStructureViewElement(PsiElement element, HarbourStructureViewElement parent, boolean isImplementation) {
        this.element = element;
        this.parent = parent;
        this.isImplementation = isImplementation;

        // Determine element type and name
        if (element instanceof LeafPsiElement) {
            this.elementType = ((LeafPsiElement)element).getElementType().toString();

            // For function/procedure/class/method keywords, find the identifier following them
            if (elementType.equals(FUNCTION_TOKEN) ||
                    elementType.equals(PROCEDURE_TOKEN) ||
                    elementType.equals(CLASS_TOKEN) ||
                    elementType.equals(METHOD_TOKEN) ||
                    elementType.equals(DATA_TOKEN)) {

                // Look for identifier after this token
                String name = findNextIdentifier(element);
                this.elementName = StringUtil.isNotEmpty(name) ? name : "unnamed";
            } else {
                this.elementName = element.getText();
            }
        } else if (element instanceof PsiFile) {
            this.elementType = "FILE";
            this.elementName = ((PsiFile)element).getName();
        } else {
            this.elementType = element.getClass().getSimpleName();
            this.elementName = element.toString();
        }
    }

    private String findNextIdentifier(PsiElement element) {
        PsiElement sibling = element.getNextSibling();
        while (sibling != null) {
            if (!StringUtil.isEmptyOrSpaces(sibling.getText())) {
                return sibling.getText().trim();
            }
            sibling = sibling.getNextSibling();
        }
        return "";
    }

    public void addChild(HarbourStructureViewElement child) {
        children.add(child);
    }

    @Override
    public Object getValue() {
        return element;
    }

    @Override
    public void navigate(boolean requestFocus) {
        if (element instanceof NavigationItem) {
            ((NavigationItem) element).navigate(requestFocus);
        }
    }

    @Override
    public boolean canNavigate() {
        return element instanceof NavigationItem && ((NavigationItem) element).canNavigate();
    }

    @Override
    public boolean canNavigateToSource() {
        return element instanceof NavigationItem && ((NavigationItem) element).canNavigateToSource();
    }

    @NotNull
    @Override
    public String getAlphaSortKey() {
        return elementName;
    }

    @NotNull
    @Override
    public ItemPresentation getPresentation() {
        return new ItemPresentation() {
            @Override
            public String getPresentableText() {
                StringBuilder sb = new StringBuilder();

                if (isImplementation) {
                    sb.append("impl ");
                }

                if (elementType.equals(METHOD_TOKEN)) {
                    sb.append("METHOD ").append(elementName);
                } else if (elementType.equals(DATA_TOKEN)) {
                    sb.append("DATA ").append(elementName);
                } else if (elementType.equals(FUNCTION_TOKEN)) {
                    sb.append("FUNCTION ").append(elementName);
                } else if (elementType.equals(PROCEDURE_TOKEN)) {
                    sb.append("PROCEDURE ").append(elementName);
                } else if (elementType.equals(CLASS_TOKEN)) {
                    sb.append("CLASS ").append(elementName);
                } else {
                    sb.append(elementName);
                }

                return sb.toString();
            }

            @Override
            public String getLocationString() {
                if (element instanceof HarbourFile) {
                    return null;
                }
                return null; // To avoid duplicating the filename everywhere
            }

            @Override
            public Icon getIcon(boolean unused) {
                if (elementType.equals(FUNCTION_TOKEN)) {
                    return HarbourIcons.FILE;
                } else if (elementType.equals(PROCEDURE_TOKEN)) {
                    return HarbourIcons.FILE;
                } else if (elementType.equals(CLASS_TOKEN)) {
                    return HarbourIcons.FILE;
                } else if (elementType.equals(METHOD_TOKEN)) {
                    return isImplementation ?
                            HarbourIcons.FILE : // should use a different implementation icon
                            HarbourIcons.FILE;
                } else if (elementType.equals(DATA_TOKEN)) {
                    return HarbourIcons.FILE;
                } else if (element instanceof HarbourFile) {
                    return HarbourIcons.FILE;
                }
                return null;
            }
        };
    }

    @NotNull
    @Override
    public TreeElement[] getChildren() {
        if (!children.isEmpty()) {
            return children.toArray(new TreeElement[0]);
        }

        if (element instanceof HarbourFile) {
            HarbourFile file = (HarbourFile) element;
            LOG.info("Building structure for file: " + file.getName());

            // Process file and build hierarchical structure
            buildFileStructure(file);

            LOG.info("Added " + children.size() + " elements to structure view");
            return children.toArray(new TreeElement[0]);
        }

        return EMPTY_ARRAY;
    }

    private void buildFileStructure(HarbourFile file) {
        // First pass - find all classes and root-level functions/procedures
        List<PsiElement> rootElements = new ArrayList<>();
        Map<PsiElement, List<PsiElement>> classMembers = new HashMap<>();
        Map<String, PsiElement> methodDeclarations = new HashMap<>();
        Map<String, PsiElement> methodImplementations = new HashMap<>();

        // Map class names to their elements
        Map<String, PsiElement> classElements = new HashMap<>();

        PsiElement currentClass = null;
        String currentClassName = null;

        // Collect all leaf elements for processing
        List<PsiElement> elements = new ArrayList<>();
        PsiTreeUtil.processElements(file, e -> {
            if (e instanceof LeafPsiElement) {
                elements.add(e);
            }
            return true;
        });

        // First pass - collect class declarations and method declarations
        for (int i = 0; i < elements.size(); i++) {
            PsiElement e = elements.get(i);
            if (e instanceof LeafPsiElement) {
                LeafPsiElement leafElement = (LeafPsiElement) e;
                String type = leafElement.getElementType().toString();

                if (type.equals(CLASS_TOKEN)) {
                    currentClass = e;
                    currentClassName = findNextIdentifier(e);
                    classElements.put(currentClassName, e);
                    classMembers.put(currentClass, new ArrayList<>());
                    rootElements.add(e);
                } else if (type.equals(ENDCLASS_TOKEN)) {
                    currentClass = null;
                    currentClassName = null;
                } else if (type.equals(METHOD_TOKEN)) {
                    if (currentClass != null) {
                        // This is a method declaration within a class
                        classMembers.get(currentClass).add(e);

                        // Store for linking with implementations
                        String methodName = findNextIdentifier(e);
                        String key = currentClassName + ":" + methodName;
                        methodDeclarations.put(key, e);
                    }
                } else if (type.equals(DATA_TOKEN)) {
                    if (currentClass != null) {
                        classMembers.get(currentClass).add(e);
                    }
                } else if (type.equals(FUNCTION_TOKEN) || type.equals(PROCEDURE_TOKEN)) {
                    rootElements.add(e);
                }
            }
        }

        // Second pass - find method implementations outside classes
        for (int i = 0; i < elements.size(); i++) {
            PsiElement e = elements.get(i);
            if (e instanceof LeafPsiElement) {
                LeafPsiElement leafElement = (LeafPsiElement) e;
                String type = leafElement.getElementType().toString();

                if (type.equals(METHOD_TOKEN) && !classMembers.values().stream().anyMatch(list -> list.contains(e))) {
                    // This is a method implementation outside a class
                    String methodName = findNextIdentifier(e);

                    // Look for className:methodName pattern
                    String fullText = e.getParent().getText();
                    for (String className : classElements.keySet()) {
                        if (fullText.contains(className + ":") ||
                                (fullText.contains(methodName) && fullText.contains("CLASS " + className))) {
                            String key = className + ":" + methodName;
                            methodImplementations.put(key, e);
                            break;
                        }
                    }
                }
            }
        }

        // Build the structure tree
        for (PsiElement rootElement : rootElements) {
            String type = ((LeafPsiElement)rootElement).getElementType().toString();

            if (type.equals(CLASS_TOKEN)) {
                String className = findNextIdentifier(rootElement);
                HarbourStructureViewElement classNode = new HarbourStructureViewElement(rootElement, this);
                this.addChild(classNode);

                // Add methods and data to class node
                List<PsiElement> members = classMembers.get(rootElement);
                if (members != null) {
                    for (PsiElement member : members) {
                        String memberType = ((LeafPsiElement)member).getElementType().toString();

                        if (memberType.equals(METHOD_TOKEN)) {
                            String methodName = findNextIdentifier(member);
                            String key = className + ":" + methodName;

                            // Add method declaration
                            HarbourStructureViewElement memberNode = new HarbourStructureViewElement(member, classNode);
                            classNode.addChild(memberNode);

                            // If we have an implementation, add it as child of the declaration
                            if (methodImplementations.containsKey(key)) {
                                PsiElement implElement = methodImplementations.get(key);
                                HarbourStructureViewElement implNode = new HarbourStructureViewElement(
                                        implElement, memberNode, true);
                                memberNode.addChild(implNode);
                            }
                        } else {
                            // Add data as regular node
                            HarbourStructureViewElement memberNode = new HarbourStructureViewElement(member, classNode);
                            classNode.addChild(memberNode);
                        }
                    }
                }
            } else {
                // Add functions and procedures to root
                this.addChild(new HarbourStructureViewElement(rootElement, this));
            }
        }
    }
}
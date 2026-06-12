function EnlargeFont()
    % Get all elements with FontSize property
    all_fonts = findall(gcf, '-property', 'FontSize');
    
    % Exclude elements with 'NoEnlarge' tag
    to_enlarge = all_fonts(~strcmp(get(all_fonts, 'Tag'), 'NoEnlarge'));
    set(to_enlarge, 'FontSize', 30);
    
    % Handle axes and legends separately (they usually don't have the tag)
    set(findall(gcf, 'Type', 'Axes'), 'FontSize', 28)
    set(findall(gcf, 'Type', 'Legend'), 'FontSize', 24)
end
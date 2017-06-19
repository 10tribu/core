<?php
if (!isConnect()) {
	throw new Exception('{{401 - Accès non autorisé}}');
}

if (init('object_id') == '') {
	$object = object::byId($_SESSION['user']->getOptions('defaultDashboardObject'));
} else {
	$object = object::byId(init('object_id'));
}
if (!is_object($object)) {
	$object = object::rootObject();
}
if (!is_object($object)) {
	throw new Exception('{{Aucun objet racine trouvé. Pour en créer un, allez dans Outils -> Objet.<br/> Si vous ne savez pas quoi faire ou que c\'est la première fois que vous utilisez Jeedom n\'hésitez pas à consulter cette <a href="https://jeedom.com/doc/documentation/premiers-pas/fr_FR/doc-premiers-pas.html" target="_blank">page</a> et celle-là si vous avez un pack : <a href="https://jeedom.com/start" target="_blank">page</a>}}');
}
$child_object = object::buildTree($object);
?>

<div class="row row-overflow">
	<?php
if ($_SESSION['user']->getOptions('displayObjetByDefault') == 1) {
	echo '<div class="col-lg-2 col-md-3 col-sm-4" id="div_displayObjectList">';
} else {
	echo '<div class="col-lg-2 col-md-3 col-sm-4" style="display:none;" id="div_displayObjectList">';
}
?>
	<div class="bs-sidebar">
		<ul id="ul_object" class="nav nav-list bs-sidenav">
			<li class="nav-header">{{Liste objets}} </li>
			<li class="filter" style="margin-bottom: 5px;"><input class="filter form-control input-sm" placeholder="{{Rechercher}}" style="width: 100%"/></li>
			<?php
$allObject = object::buildTree(null, true);
foreach ($allObject as $object_li) {
	$margin = 15 * $object_li->getConfiguration('parentNumber');
	if ($object_li->getId() == $object->getId()) {
		echo '<li class="cursor li_object active" ><a data-object_id="' . $object_li->getId() . '" data-href="index.php?v=d&p=dashboard&object_id=' . $object_li->getId() . '&category=' . init('category', 'all') . '&summary=' . init('summary') . '"><span style="position:relative;left:' . $margin . 'px;">' . $object_li->getHumanName(true) . '</span></a></li>';
	} else {
		echo '<li class="cursor li_object" ><a data-object_id="' . $object_li->getId() . '" data-href="index.php?v=d&p=dashboard&object_id=' . $object_li->getId() . '&category=' . init('category', 'all') . '&summary=' . init('summary') . '"><span style="position:relative;left:' . $margin . 'px;">' . $object_li->getHumanName(true) . '</span></a></li>';
	}
}
?>
		</ul>
	</div>
</div>
<?php
if ($_SESSION['user']->getOptions('displayScenarioByDefault') == 1) {
	if ($_SESSION['user']->getOptions('displayObjetByDefault') == 1) {
		echo '<div class="col-lg-8 col-md-7 col-sm-5" id="div_displayObject">';
	} else {
		echo '<div class="col-lg-10 col-md-9 col-sm-7" id="div_displayObject">';
	}
} else {
	if ($_SESSION['user']->getOptions('displayObjetByDefault') == 1) {
		echo '<div class="col-lg-10 col-md-9 col-sm-8" id="div_displayObject">';
	} else {
		echo '<div class="col-lg-12 col-md-12 col-sm-12" id="div_displayObject">';
	}
}
?>
<i class='fa fa-picture-o cursor pull-left' id='bt_displayObject' data-display='<?php echo $_SESSION['user']->getOptions('displayObjetByDefault') ?>' title="{{Afficher/Masquer les objets}}"></i>
<i class='fa fa-cogs pull-right cursor' id='bt_displayScenario' data-display='<?php echo $_SESSION['user']->getOptions('displayScenarioByDefault') ?>' title="{{Afficher/Masquer les scénarios}}"></i>
<?php if (init('category', 'all') == 'all') {?>
<i class="fa fa-pencil pull-right cursor" id="bt_editDashboardWidgetOrder" data-mode="0" style="margin-right : 10px;"></i>
<?php }
?>
<div style="text-align : center;">
	<?php
if (init('category', 'all') == 'all') {
	echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=all&summary=' . init('summary') . '" class="btn btn-primary btn-sm categoryAction" style="margin-bottom: 5px;margin-right: 3px;">{{Tous}}</a>';
} else {
	echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=all&summary=' . init('summary') . '" class="btn btn-default btn-sm categoryAction" style="margin-bottom: 5px;margin-right: 3px;">{{Tous}}</a>';
}
foreach (jeedom::getConfiguration('eqLogic:category', true) as $key => $value) {
	if (init('category', 'all') == $key) {
		echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=' . $key . '&summary=' . init('summary') . '" class="btn btn-primary btn-sm categoryAction" data-l1key="' . $key . '" style="margin-bottom: 5px;margin-right: 3px;">{{' . $value['name'] . '}}</a>';
	} else {
		echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=' . $key . '&summary=' . init('summary') . '" class="btn btn-default btn-sm categoryAction" data-l1key="' . $key . '" style="margin-bottom: 5px;margin-right: 3px;">{{' . $value['name'] . '}}</a>';
	}
}
if (init('category', 'all') == 'other') {
	echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=other&summary=' . init('summary') . '" class="btn btn-primary btn-sm categoryAction" style="margin-bottom: 5px;margin-right: 3px;">{{Autre}}</a>';
} else {
	echo '<a href="index.php?v=d&p=dashboard&object_id=' . init('object_id') . '&category=other&summary=' . init('summary') . '" class="btn btn-default btn-sm categoryAction" style="margin-bottom: 5px;margin-right: 3px;">{{Autre}}</a>';
}
?>
</div>
<?php include_file('desktop', 'dashboard', 'js');?>
<?php
echo '<div id="' . $object->getName() . '" data-object_id="' . $object->getId() . '" class="div_object ' . $object->getName() . '">';
echo '<legend ><a class="div_object" style="text-decoration:none" href="index.php?v=d&p=object&id=' . $object->getId() . '">'. $object->getDisplay('icon') . '</a> ' . $object->getName() . '<span style="font-size : 0.6em;margin-left:10px;">' . $object->getHtmlSummary() . '</span></legend>';
echo '<div class="div_displayEquipement" id="div_ob' . $object->getId() . '">';
echo '<script>getObjectHtml(' . $object->getId() . ')</script>';
echo '</div>';
echo '</div>';
foreach ($child_object as $child) {
	echo '<div id="' . $child->getName() . '" data-object_id="' . $child->getId() . '" class="div_object ' . $child->getName() . '">';
	echo '<legend ><a style="text-decoration:none" href="index.php?v=d&p=object&id='. $child->getId() . '">' . $child->getDisplay('icon') . '</a> ' . $child->getName() . '<span style="font-size : 0.6em;margin-left:10px;">' . $child->getHtmlSummary() . '</span></legend>';
	echo '<div class="div_displayEquipement" id="div_ob' . $child->getId() . '">';
	echo '<script>getObjectHtml(' . $child->getId() . ')</script>';
	echo '</div>';
	echo '</div>';
}

?>
</div>
<?php
if ($_SESSION['user']->getOptions('displayScenarioByDefault') == 1) {
	echo '<div class="col-lg-2 col-md-2 col-sm-3" id="div_displayScenario">';
} else {
	echo '<div class="col-lg-2 col-md-2 col-sm-3" id="div_displayScenario" style="display:none;">';
}
?>
<legend><i class="fa fa-history"></i> {{Scénarios}}</legend>
<?php
foreach (scenario::all() as $scenario) {
	if ($scenario->getIsVisible() == 0) {
		continue;
	}
	echo $scenario->toHtml('dashboard');
}
?>
</div>
</div>
<style>
.scenario-widget{
	margin-top: 2px !important;
}
</style>
